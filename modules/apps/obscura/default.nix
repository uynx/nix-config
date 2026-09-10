{
  self,
  inputs,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.obscura = moduleWithSystem (
    { inputs', ... }:
    { pkgs, ... }:
    let
      upstream = inputs'.obscuravpn.packages;

      obscura-gui = pkgs.runCommand "obscura-gui" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
        mkdir -p $out/bin
        makeWrapper ${upstream.rust-gui-bin}/bin/obscura-gui $out/bin/obscura-gui \
          --set GDK_PIXBUF_MODULE_FILE \
            "${pkgs.librsvg}/${builtins.dirOf pkgs.gdk-pixbuf.moduleDir}/loaders.cache"
      '';

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

            ip daddr 255.255.255.255 udp sport 68 udp dport 67 accept
            ip6 daddr ff02::1:2 udp sport 546 udp dport 547 accept
            icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } accept

            udp dport 53 accept
            tcp dport 53 accept
            tcp dport 853 accept
            ip daddr 194.242.2.9 tcp dport 443 accept
            ip6 daddr 2a07:e340::9 tcp dport 443 accept

            ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 224.0.0.0/24, 239.0.0.0/8, 255.255.255.255 } accept
            ip6 daddr { fe80::/10, fc00::/7, ff01::/16, ff02::/16, ff03::/16, ff04::/16, ff05::/16 } accept
          }
        }
      '';

      obscura-gui-desktop = pkgs.runCommand "obscura-gui-desktop" { } ''
        install -Dm444 ${inputs.obscuravpn}/linux/common/net.obscura.vpn.gui.desktop \
          $out/share/applications/net.obscura.vpn.gui.desktop

        for px in 64 128 256; do
          install -Dm444 ${inputs.obscuravpn}/linux/common/icons/''${px}x''${px}/net.obscura.vpn.gui.png \
            $out/share/icons/hicolor/''${px}x''${px}/apps/net.obscura.vpn.gui.png
        done
      '';
    in
    {
      environment.systemPackages = [
        obscura
        obscura-gui
        obscura-gui-desktop
      ];

      systemd.services.obscura-lockdown = {
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
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.nftables}/bin/nft -f ${lockdown-rules}";
          ExecStop = "${pkgs.nftables}/bin/nft destroy table inet obscura-lockdown";
        };
      };

      systemd.services.obscura = {
        description = "Obscura VPN";
        wantedBy = [ "multi-user.target" ];
        wants = [ "NetworkManager.service" ];
        after = [
          "network.target"
          "NetworkManager.service"
        ];

        startLimitIntervalSec = 0;

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

      systemd.services.obscura-connect = {
        description = "Obscura VPN tunnel";
        wantedBy = [ "multi-user.target" ];
        requires = [ "obscura.service" ];
        after = [ "obscura.service" ];

        restartIfChanged = false;

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/timeout 90 ${obscura}/bin/obscura connect";
          TimeoutStartSec = 120;
          SuccessExitStatus = "SIGTERM 124";
        };
      };

      users.groups.obscura = { };
      users.users.${self.lib.user.name}.extraGroups = [ "obscura" ];
    }
  );

  flake.homeModules.obscura = {
    shellHooks.rebPostSwitch = ''
      sudo systemctl try-restart obscura.service
      obscura connect
    '';

    programs.fish.functions.vpn.body = ''
      switch "$argv[1]"
          case fix
              sudo systemctl restart obscura.service
              obscura connect
          case off
              sudo systemctl stop obscura.service obscura-lockdown.service
          case on
              sudo systemctl start obscura-lockdown.service obscura.service
              obscura connect
          case '*'
              echo "vpn fix  restart the daemon, kill switch stays on"
              echo "vpn off  daemon and kill switch off — unprotected network"
              echo "vpn on   both back"
              obscura status
      end
    '';
  };
}
