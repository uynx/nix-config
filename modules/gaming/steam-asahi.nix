{
  # Docker backs the Fedora/distrobox container the Steam stack runs in.
  flake.nixosModules.steamAsahi = {
    virtualisation.docker.enable = true;
  };
}
