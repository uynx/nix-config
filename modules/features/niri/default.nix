{
  # niri config is plain KDL and live-reloads on save, so it stays a real file
  # rather than being generated from Nix attrs.
  flake.homeModules.niri = {
    home.file.".config/niri/config.kdl".source = ./config.kdl;
  };
}
