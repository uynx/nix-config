{
  # niri config is plain KDL and live-reloads on save, so it stays a real file
  # rather than being generated from Nix attrs. The one substitution is the
  # xwayland-satellite binary, which has to be an absolute store path.
  flake.homeModules.niri =
    { pkgs, lib, ... }:
    {
      home.file.".config/niri/config.kdl".source = pkgs.replaceVars ./config.kdl {
        xwaylandSatellite = lib.getExe pkgs.xwayland-satellite;
      };
    };
}
