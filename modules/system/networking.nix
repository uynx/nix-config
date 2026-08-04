{
  # hostName is per-host, set in modules/hosts/<name>/default.nix
  flake.nixosModules.networking = {
    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";

      # NetworkManager owns the MAC even under the iwd backend, so randomize
      # here and leave iwd's own AddressRandomization alone — two randomizers
      # fight over the same interface. "random" is a fresh MAC per connect;
      # drop to "stable" if a router's DHCP reservation or a captive portal
      # starts breaking on reconnect.
      wifi.macAddress = "random";
      ethernet.macAddress = "random";
    };
  };
}
