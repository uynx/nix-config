{
  # Docker backs the Fedora/distrobox container the Steam stack runs in.
  flake.nixosModules.steamAsahi = { pkgs, ... }: {
    virtualisation.docker.enable = true;
    virtualisation.waydroid = {
      enable = true;
      package = pkgs.waydroid-nftables;
    };
  };
}
