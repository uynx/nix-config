{
  # hostName is per-host, set in modules/hosts/<name>/default.nix
  flake.nixosModules.networking = {
    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";

      # Wifi randomization lives in iwd below, not here: under the iwd backend
      # iwd owns the interface MAC and NetworkManager's cloned-mac-address is
      # a no-op. This line only covers wired.
      ethernet.macAddress = "random";

      # Defaults to yes; a constant option-12 hostname tracks better than the
      # MAC it would otherwise undo.
      settings.connection."ipv4.dhcp-send-hostname" = false;
    };

    # "network" keeps the MAC distinct per SSID so two venues can never
    # correlate. "nic" preserves Apple vendor OUI to avoid synthetic OUI flags.
    networking.wireless.iwd.settings.General = {
      AddressRandomization = "network";
      AddressRandomizationRange = "nic";
    };

    # Per-SSID alone still gives a venue a stable pseudonym across visits.
    # AlwaysRandomizeAddress re-rolls it every connection, and only works under
    # AddressRandomization="network". It is per-network state under /var/lib/iwd
    # with no NixOS option and no global equivalent, hence patching at boot & on change.
    systemd.services.iwd-randomize-known-networks = {
      description = "Force per-connection MAC randomization on every known network";
      wantedBy = [ "multi-user.target" ];
      after = [ "iwd.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        shopt -s nullglob
        for f in /var/lib/iwd/*.psk /var/lib/iwd/*.open /var/lib/iwd/*.8021x; do
          grep -q '^AlwaysRandomizeAddress' "$f" && continue
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
