{
  # hostName is per-host, set in modules/hosts/<name>/default.nix
  flake.nixosModules.networking = {
    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };
  };
}
