{ self, ... }:
{
  # hostName is per-host, set in modules/hosts/<name>/default.nix
  flake.nixosModules.networking =
    { pkgs, ... }:
    {
      # Boot otherwise blocks on this unit until it times out whenever Wi-Fi is
      # slow to associate, and nothing here needs the network that early.
      systemd.services.NetworkManager-wait-online.enable = false;

      # A changed unit is stopped in the switch's stop phase and started again
      # only in its start phase, which is *after* the restart phase where Home
      # Manager activation runs. Left default, every bump of either daemon takes
      # the machine offline for the whole activation and anything in it that
      # touches the network deadlocks the rebuild. False moves them into the
      # restart phase instead: one `systemctl restart`, seconds of downtime.
      # Its documented cost is running the new ExecStop; neither unit has one.
      systemd.services.NetworkManager.stopIfChanged = false;
      systemd.services.iwd.stopIfChanged = false;

      # Restarted in that same phase, so order it behind them — user units are
      # started from inside this one and must never land in the restart gap.
      systemd.services."home-manager-${self.lib.user.name}".after = [
        "NetworkManager.service"
        "iwd.service"
      ];

      # NixOS' default pool is `*.nixos.pool.ntp.org`, which announces the distro
      # to the pool operator and to anything watching the exit. Generic pools say
      # only "a Linux host".
      networking.timeServers = [
        "time.cloudflare.com"
        "0.pool.ntp.org"
        "1.pool.ntp.org"
      ];

      services.dnscrypt-proxy = {
        enable = true;
        settings = {
          listen_addresses = [
            "127.0.0.1:53"
            "[::1]:53"
          ];
          server_names = [
            "mullvad-all-doh"
            "mullvad-all-doh-v6"
          ];
          doh_servers = true;
          require_dnssec = false;
          static = {
            mullvad-all-doh.stamp =
              "sdns://AgIAAAAAAAAADzE5NC4yNDIuMi45OjQ0MwATYWxsLmRucy5tdWxsdmFkLm5ldAovZG5zLXF1ZXJ5";
            mullvad-all-doh-v6.stamp =
              "sdns://AgIAAAAAAAAAElsyYTA3OmUzNDA6OjldOjQ0MwATYWxsLmRucy5tdWxsdmFkLm5ldAovZG5zLXF1ZXJ5";
          };
        };
      };

      networking.networkmanager = {
        enable = true;
        wifi.backend = "iwd";

        # Wifi randomization lives in iwd below, not here: under the iwd backend
        # iwd owns the interface MAC and NetworkManager's cloned-mac-address is
        # a no-op. This line only covers wired.
        ethernet.macAddress = "random";

        # Defaults to yes; a constant option-12 hostname tracks better than the
        # MAC it would otherwise undo. Enforce RFC 8981 temporary IPv6 privacy addresses.
        settings.connection = {
          "ipv4.dhcp-send-hostname" = false;
          "ipv6.ip6-privacy" = 2;
        };

        # NM learns where to write iwd's provisioning files by asking iwd over
        # D-Bus when the default "auto" is in effect. NetworkManager-ensure-profiles
        # runs moments after NM starts and lost that race at every boot: no path
        # meant no conversion, and an 802.1X profile without a provisioning file
        # cannot activate at all. Naming the directory removes the query.
        settings.main.iwd-config-path = "/var/lib/iwd";

        # Probes nmcheck.gnome.org on every association — before the VPN is up, so
        # it hands the real IP to a third party on each boot. Interval 0 is NM's
        # documented off switch; the egress lockdown would block it anyway and
        # leave NM permanently reporting "limited".
        settings.connectivity.interval = 0;
      };

      # With the probe above off and resolv.conf pointing at the VPN resolver, a
      # captive network resolves nothing and the portal never loads. Run
      # `captive-browser` by hand there: it pins DNS and sockets to wlan0's DHCP
      # server, bypassing both. Do not "fix" this by re-enabling the probe.
      programs.captive-browser = {
        enable = true;
        interface = "wlan0";
        # Upstream default is pkgs.chromium, a second full browser in the closure.
        browser = ''
          env XDG_CONFIG_HOME="$PREV_CONFIG_HOME" ${pkgs.ungoogled-chromium}/bin/chromium \
            --user-data-dir="''${XDG_DATA_HOME:-$HOME/.local/share}/chromium-captive" \
            --proxy-server="socks5://$PROXY" --proxy-bypass-list="<-loopback>" \
            --no-first-run --new-window --incognito http://cache.nixos.org/
        '';
      };

      # "network" keeps the MAC distinct per SSID so two venues can never
      # correlate. "nic" preserves Apple vendor OUI to avoid synthetic OUI flags.
      networking.wireless.iwd.settings = {
        General = {
          AddressRandomization = "network";
          AddressRandomizationRange = "nic";
        };
        Scan.DisablePeriodicScan = true;
      };

      # Per-SSID alone still gives a venue a stable pseudonym across visits.
      # AlwaysRandomizeAddress re-rolls it every connection, and only works under
      # AddressRandomization="network". It is per-network state under /var/lib/iwd
      # with no NixOS option and no global equivalent, hence patching at boot & on change.
      systemd.services.iwd-randomize-known-networks = {
        description = "Force per-connection MAC randomization on every known network";
        wantedBy = [ "multi-user.target" ];
        after = [ "iwd.service" ];
        # The unit edits the directory its own .path unit watches, so each run
        # retriggers it until every profile is patched. That convergence burst
        # trips the default 5-starts-per-10 s limit and fails a unit whose work
        # succeeded every time, which is enough to exit a rebuild non-zero.
        startLimitIntervalSec = 0;
        serviceConfig.Type = "oneshot";
        script = ''
          shopt -s nullglob
          for f in /var/lib/iwd/*.psk /var/lib/iwd/*.open /var/lib/iwd/*.8021x; do
            # NetworkManager rewrites .8021x files in place, so one can vanish
          # between the glob and the read. Without this guard grep fails and
          # errexit takes the whole unit down mid-activation.
          [ -e "$f" ] || continue
          if grep -q '^AlwaysRandomizeAddress' "$f"; then continue; fi
            # Append-only/insert-only: never rewrite the file, it holds the PSK.
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
