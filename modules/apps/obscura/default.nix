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

      # The sidebar icons are symbolic SVGs baked into the binary as a GResource, and
      # GTK renders SVG through gdk-pixbuf's librsvg loader. rust-gui-bin ships
      # unwrapped, so without this the whole sidebar falls back to "image-missing".
      obscura-gui = pkgs.runCommand "obscura-gui" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
        mkdir -p $out/bin
        makeWrapper ${upstream.rust-gui-bin}/bin/obscura-gui $out/bin/obscura-gui \
          --set GDK_PIXBUF_MODULE_FILE \
            "${pkgs.librsvg}/${builtins.dirOf pkgs.gdk-pixbuf.moduleDir}/loaders.cache"
      '';

      # Upstream sets OBSCURA_VERSION on rust-gui-bin but not on rust-cli-bin, so the
      # daemon compiles with version.rs's "v0.0.0-dev" fallback and the GUI refuses to
      # talk to it. upstream.version is the exact string the GUI was stamped with.
      obscura = upstream.rust-cli-bin.overrideAttrs (_: {
        OBSCURA_VERSION = builtins.readFile upstream.version;
      });

      # Obscura's own kill switch is installed by the daemon and only exists while it
      # holds a tunnel, so boot until first connect (~12 s here) has no egress filter
      # at all. This table is ours, is up before the network is, and mirrors their
      # allow-list. Escape hatch if it ever locks the machine out of the network:
      # `systemctl stop obscura-lockdown`. Re-enabling Mullvad means allowing its
      # interface and fwmark here too, or its daemon will never reach its API.
      lockdown-rules = pkgs.writeText "obscura-lockdown.nft" ''
        table inet obscura-lockdown
        delete table inet obscura-lockdown

        table inet obscura-lockdown {
          chain egress {
            type filter hook postrouting priority filter + 10; policy drop;

            oifname "lo" accept

            # The daemon marks its own API and relay sockets (rustlib/src/net.rs,
            # FWMARK = b"obsc"), which is what lets it reach the network to bring
            # the tunnel up without punching a general hole.
            meta mark 0x6f627363 accept
            oifname "obscuravpn" accept

            # Without these the interface never gets an address in the first place.
            ip daddr 255.255.255.255 udp sport 68 udp dport 67 accept
            ip6 daddr ff02::1:2 udp sport 546 udp dport 547 accept
            icmpv6 type { nd-router-solicit, nd-neighbor-solicit, nd-neighbor-advert } accept

            # The daemon resolves v1.api.prod.obscura.net with getaddrinfo on an
            # *unmarked* socket (rustlib/src/dns.rs), so dropping 53 deadlocks the
            # tunnel on any network whose DHCP resolver is off-LAN. This is the one
            # deliberate pre-tunnel leak left.
            udp dport 53 accept
            tcp dport 53 accept

            ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 224.0.0.0/24, 239.0.0.0/8, 255.255.255.255 } accept
            ip6 daddr { fe80::/10, fc00::/7, ff01::/16, ff02::/16, ff03::/16, ff04::/16, ff05::/16 } accept
          }
        }
      '';

      # rust-gui-bin is only the binary; upstream keeps the launcher and icons in
      # its distro packaging directory, so pull them straight off the flake source.
      obscura-gui-desktop = pkgs.runCommand "obscura-gui-desktop" { } ''
        install -Dm444 ${inputs.obscuravpn}/linux/common/net.obscura.vpn.gui.desktop \
          $out/share/applications/net.obscura.vpn.gui.desktop

        # The tray icon lives in the GUI process, so the only way to have one is to
        # run the GUI. /etc/xdg is not on XDG_CONFIG_DIRS here — the autostart
        # generator scans the system profile's copy of it, which this lands in.
        install -Dm444 ${inputs.obscuravpn}/linux/common/net.obscura.vpn.gui.desktop \
          $out/etc/xdg/autostart/net.obscura.vpn.gui.desktop
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

      # Ordered like NixOS' own firewall unit: default-deny has to be in place
      # before anything can put a packet on the wire.
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

      # The CLI asks systemd over D-Bus for a unit called exactly "obscura.service"
      # to report status, so renaming this makes it report "not installed".
      systemd.services.obscura = {
        description = "Obscura VPN";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];

        # The kill-switch nftables table is owner-flagged, so the kernel destroys it
        # with the daemon — a daemon that gives up leaves the machine unfiltered, not
        # fail-closed. Never stop retrying, matching upstream's unit.
        startLimitIntervalSec = 0;

        # A switch stops this unit in its stop phase and only starts it again in its
        # start phase, with the whole activation script in between — and obscura-lockdown
        # stays up throughout, so that gap is a total network blackout. Home Manager's
        # activation runs in that gap and blocks for 90 s per try on the rclone Drive
        # mount, which is the rebuild that never says "finished". Interrupting it there
        # leaves the daemon stopped and the machine locked out until reboot. `reb`
        # restarts it after the switch instead, where nothing else is waiting.
        restartIfChanged = false;

        serviceConfig = {
          ExecStart = "${obscura}/bin/obscura service --dns network-manager";
          # The daemon binds /run/obscura.sock without chowning it, so the socket
          # inherits the unit's group and mode — clients check membership of the
          # owning group, and connecting to a unix socket needs write permission.
          Group = "obscura";
          UMask = "0007";
          # --config-dir and --log-dir are required and read $STATE_DIRECTORY and
          # $LOGS_DIRECTORY, so dropping either directive makes the daemon exit 2.
          StateDirectory = "obscura";
          StateDirectoryMode = "0700";
          LogsDirectory = "obscura";
          LogsDirectoryMode = "0700";

          # The daemon parks its nftables netlink socket in the fd store so the
          # kill-switch table survives a restart instead of dying with the socket.
          # It pushes the fd unconditionally, so without a non-zero store max that
          # push is silently discarded and every restart reopens the window.
          Type = "notify";
          FileDescriptorStoreMax = 8;

          Restart = "always";
          RestartSec = 1;
          RestartSteps = 5;
          RestartMaxDelaySec = 30;
        };
      };

      # The daemon can never bring up its own tunnel at boot: the Linux service
      # hands Manager::new force_init_inactive = true, which clears the persisted
      # `tunnel_active` before the socket is even served, and `auto_connect` is
      # read only by the Apple and Android clients. Do not go back to patching
      # `auto_connect` into config.json — nothing on this platform reads it.
      systemd.services.obscura-connect = {
        description = "Obscura VPN tunnel";
        wantedBy = [ "multi-user.target" ];
        requires = [ "obscura.service" ];
        after = [ "obscura.service" ];

        # A switch would otherwise stop and start this mid-activation, and the
        # command below blocks, so an offline machine would stall there.
        restartIfChanged = false;

        serviceConfig = {
          Type = "oneshot";
          # `connect` sets the target state over IPC and only then blocks watching
          # status, so the timeout cuts the watching short, not the request — the
          # daemon keeps retrying the tunnel on its own afterwards.
          ExecStart = "${obscura}/bin/obscura connect";
          TimeoutStartSec = 90;
          SuccessExitStatus = "SIGTERM";
        };
      };

      # Membership belongs beside the group, not in `system/user.nix`: a host
      # without this bundle would otherwise name a group nothing declares.
      users.groups.obscura = { };
      users.users.${self.lib.user.name}.extraGroups = [ "obscura" ];
    }
  );

  # Both of these used to live in the fish wrapper, which meant a host that
  # dropped this bundle kept a `vpn` command driving units it no longer had.
  flake.homeModules.obscura = {
    # obscura.service is restartIfChanged = false, so a switch is the one thing
    # that never lands a new daemon binary. It has to run after the switch:
    # restarting it during one deadlocks activation. A restarted daemon always
    # comes back disconnected, and obscura-connect.service only runs at boot, so
    # the tunnel has to be asked for again here.
    shellHooks.rebPostSwitch = ''
      sudo systemctl try-restart obscura.service
      obscura connect
    '';

    # Escape hatch for the state where the daemon is down but obscura-lockdown
    # is still filtering, which is a machine with no network at all.
    programs.fish.functions.vpn.body = ''
      switch "$argv[1]"
          case fix
              sudo systemctl restart obscura.service
          case off
              sudo systemctl stop obscura.service obscura-lockdown.service
          case on
              sudo systemctl start obscura-lockdown.service obscura.service
          case '*'
              echo "vpn fix  restart the daemon, kill switch stays on"
              echo "vpn off  daemon and kill switch off — unprotected network"
              echo "vpn on   both back"
              obscura status
      end
    '';
  };
}
