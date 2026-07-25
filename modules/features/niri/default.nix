{
  # niri config is plain KDL and live-reloads on save, so it stays a real file
  # rather than being generated from Nix attrs. The one substitution is the
  # xwayland-satellite binary, which has to be an absolute store path.
  #
  # Done with replaceStrings rather than pkgs.replaceVars: the latter fails the
  # build on any leftover @identifier@, and wpctl's @DEFAULT_AUDIO_SINK@ /
  # @DEFAULT_AUDIO_SOURCE@ are literal syntax, not placeholders.
  flake.homeModules.niri =
    { pkgs, lib, ... }:
    {
      home.file.".config/niri/config.kdl".text =
        builtins.replaceStrings [ "@xwaylandSatellite@" ] [ (lib.getExe pkgs.xwayland-satellite) ]
          (builtins.readFile ./config.kdl);
    };
}
