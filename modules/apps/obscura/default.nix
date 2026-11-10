{
  self,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.obscura = moduleWithSystem (
    { inputs', ... }:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      upstream = inputs'.obscuravpn.packages;

      # sops-nix fails activation on a declared key that secrets.yaml lacks; key names are plaintext.
      hasAccount = lib.hasInfix "\nobscura-account:" (builtins.readFile ../../../secrets/secrets.yaml);

      obscura = upstream.rust-cli-bin.overrideAttrs (_: {
        OBSCURA_VERSION = builtins.readFile upstream.version;
      });

      lockdown-rules = pkgs.writeText "obscura-lockdown.nft" ''
        table inet obscura-lockdown
        delete table inet obscura-lockdown

        table inet obscura-lockdown {
          chain egress {
            type filter hook postrouting priority filter + 10; policy drop;

            oifname "lo" accept

            meta mark 0x6f627363 accept
            oifname "obscuravpn" accept
            oifname "tailscale0" accept
            meta mark & 0xff0000 == 0x80000 accept

            ip daddr 255.255.255.255 udp sport 68 udp dport 67 accept
            ip6 daddr ff02::1:2 udp sport 546 udp dport 547 accept
            icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } accept

            udp dport 53 accept
            tcp dport 53 accept
            tcp dport 853 accept
            # Keep these endpoints aligned with system/dns-stamps.json.
            ip daddr 149.112.112.112 tcp dport 443 accept
            ip6 daddr 2620:fe::fe tcp dport 443 accept

            ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 224.0.0.0/24, 239.0.0.0/8, 255.255.255.255 } accept
            ip6 daddr { fe80::/10, fc00::/7, ff01::/16, ff02::/16, ff03::/16, ff04::/16, ff05::/16 } accept
          }
        }
      '';

    in
    {
      environment.systemPackages = [ obscura ];

      # Runs before the switch restarts units, so a VPN turned off under the old /run flag stays off.
      system.activationScripts.obscuraOffFlag = ''
        if [ -e /run/obscura-off ]; then touch /var/lib/obscura-off; fi
      '';

      systemd.services = {
        obscura-lockdown = {
          description = "Obscura egress lockdown";
          wantedBy = [ "sysinit.target" ];
          before = [
            "network-pre.target"
            "shutdown.target"
          ];
          wants = [ "network-pre.target" ];
          conflicts = [ "shutdown.target" ];
          unitConfig = {
            DefaultDependencies = false;
            ConditionCapability = "CAP_NET_ADMIN";
            # vpn off writes this flag, so a switch or a reboot leaves the VPN off until vpn on; keep it off tmpfs.
            ConditionPathExists = "!/var/lib/obscura-off";
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.nftables}/bin/nft -f ${lockdown-rules}";
            ExecStop = "${pkgs.nftables}/bin/nft destroy table inet obscura-lockdown";
          };
        };

        obscura = {
          description = "Obscura VPN";
          wantedBy = [ "multi-user.target" ];
          wants = [ "NetworkManager.service" ];
          after = [
            "network.target"
            "NetworkManager.service"
          ];

          startLimitIntervalSec = 0;
          unitConfig.ConditionPathExists = "!/var/lib/obscura-off";

          restartIfChanged = false;

          serviceConfig = {
            ExecStart = "${obscura}/bin/obscura service --dns network-manager";
            Group = "obscura";
            UMask = "0007";
            StateDirectory = "obscura";
            StateDirectoryMode = "0700";
            LogsDirectory = "obscura";
            LogsDirectoryMode = "0700";

            Type = "notify";
            FileDescriptorStoreMax = 8;

            Restart = "always";
            RestartSec = 1;
            RestartSteps = 5;
            RestartMaxDelaySec = 30;
          };
        };

        obscura-connect = {
          description = "Obscura VPN tunnel";
          wantedBy = [ "multi-user.target" ];
          requires = [ "obscura.service" ];
          after = [ "obscura.service" ];
          unitConfig.ConditionPathExists = "!/var/lib/obscura-off";

          restartIfChanged = false;

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStartPre = lib.mkIf hasAccount (
              pkgs.writeShellScript "obscura-login" ''
                ${obscura}/bin/obscura status 2>&1 | ${pkgs.gnugrep}/bin/grep -q 'Not logged in' || exit 0
                ${pkgs.coreutils}/bin/timeout 60 ${obscura}/bin/obscura login "$(< ${config.sops.secrets.obscura-account.path})"
              ''
            );
            ExecStart = "${pkgs.coreutils}/bin/timeout 90 ${obscura}/bin/obscura connect";
            TimeoutStartSec = 120;
            SuccessExitStatus = "SIGTERM 124";
          };
        };
      };

      sops.secrets = lib.mkIf hasAccount { obscura-account = { }; };

      users.groups.obscura = { };
      users.users.${self.lib.user.name}.extraGroups = [ "obscura" ];
    }
  );

  flake.homeModules.obscura = {
    shellHooks.rebSnapshot = ''
      set -l obscuraWasOn 0
      if systemctl is-active --quiet obscura.service
            set obscuraWasOn -1
            set -l obscuraState (timeout 5 obscura status 2>/dev/null)
            if printf '%s\n' $obscuraState | string match -qr '^VPN is (connected|connecting)'
              set obscuraWasOn 1
            else if printf '%s\n' $obscuraState | string match -qr '^VPN is disconnected'
                set obscuraWasOn 0
          end
      end
    '';
    shellHooks.rebPostSwitch = ''
      if test "$obscuraWasOn" = 1
          string match -q (realpath (command -v obscura))" *" (ps -o args= -p (systemctl show -p MainPID --value obscura.service))
          or sudo systemctl try-restart obscura.service
          obscura connect
        else if test "$obscuraWasOn" = 0
          sudo systemctl stop obscura.service obscura-lockdown.service
      end
    '';

    programs.fish.functions.vpn.body = ''
      switch "$argv[1]"
          case fix
              sudo rm -f /var/lib/obscura-off
              and sudo systemctl restart dnscrypt-proxy.service obscura.service
              and obscura connect
          case off
              sudo touch /var/lib/obscura-off
              and sudo systemctl stop obscura.service obscura-lockdown.service
              and sudo systemctl restart dnscrypt-proxy.service
          case on
              sudo rm -f /var/lib/obscura-off
              and sudo systemctl start obscura-lockdown.service obscura.service
              and sudo systemctl restart dnscrypt-proxy.service
              and obscura connect
          case '*'
              echo "vpn fix  restart the daemon, kill switch stays on"
              echo "vpn off  daemon and kill switch off, survives reboot — unprotected network"
              echo "vpn on   both back"
              obscura status
      end
    '';
  };
}
