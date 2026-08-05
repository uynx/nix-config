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

    # "network" derives the MAC from SSID + permanent address, so it is stable
    # per-network — DHCP reservations and captive portals keep working. Use
    # "once" for a fresh MAC each iwd start; iwd has no per-connect option.
    networking.wireless.iwd.settings.General = {
      AddressRandomization = "network";
      AddressRandomizationRange = "full";
    };
  };
}
