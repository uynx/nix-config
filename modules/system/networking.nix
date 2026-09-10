{ self, ... }:
{
  flake.nixosModules.networking =
    { pkgs, ... }:
    {
      systemd.services.NetworkManager-wait-online.enable = false;

      systemd.services.NetworkManager.stopIfChanged = false;
      systemd.services.iwd.stopIfChanged = false;

      systemd.services."home-manager-${self.lib.user.name}".after = [
        "NetworkManager.service"
        "iwd.service"
      ];

      networking.timeServers = [
        "time.cloudflare.com"
        "0.pool.ntp.org"
        "1.pool.ntp.org"
      ];

      networking.networkmanager = {
        enable = true;
        wifi.backend = "iwd";

        ethernet.macAddress = "random";

        settings.connection = {
          "ipv4.dhcp-send-hostname" = false;
          "ipv6.ip6-privacy" = 2;
        };

        settings.main.iwd-config-path = "/var/lib/iwd";

        settings.connectivity.interval = 0;
      };

      programs.captive-browser = {
        enable = true;
        interface = "wlan0";
        browser = ''
          env XDG_CONFIG_HOME="$PREV_CONFIG_HOME" ${pkgs.ungoogled-chromium}/bin/chromium \
            --user-data-dir="''${XDG_DATA_HOME:-$HOME/.local/share}/chromium-captive" \
            --proxy-server="socks5://$PROXY" --proxy-bypass-list="<-loopback>" \
            --no-first-run --new-window --incognito http://cache.nixos.org/
        '';
      };

      networking.wireless.iwd.settings = {
        General = {
          AddressRandomization = "network";
          AddressRandomizationRange = "nic";
        };
        Scan.DisablePeriodicScan = true;
      };

      systemd.services.iwd-randomize-known-networks = {
        description = "Force per-connection MAC randomization on every known network";
        wantedBy = [ "multi-user.target" ];
        after = [ "iwd.service" ];
        startLimitIntervalSec = 0;
        serviceConfig.Type = "oneshot";
        script = ''
          shopt -s nullglob
          for f in /var/lib/iwd/*.psk /var/lib/iwd/*.open /var/lib/iwd/*.8021x; do
          [ -e "$f" ] || continue
          if grep -q '^AlwaysRandomizeAddress' "$f"; then continue; fi
            if grep -q '^\[Settings\]' "$f"; then
              sed -i '/^\[Settings\]/a AlwaysRandomizeAddress=true' "$f"
            else
              printf '\n[Settings]\nAlwaysRandomizeAddress=true\n' >> "$f"
            fi
          done
        '';
      };

      systemd.paths.iwd-randomize-known-networks = {
        description = "Watch /var/lib/iwd for new network profiles";
        wantedBy = [ "multi-user.target" ];
        pathConfig = {
          PathModified = "/var/lib/iwd";
          Unit = "iwd-randomize-known-networks.service";
        };
      };
    };
}
