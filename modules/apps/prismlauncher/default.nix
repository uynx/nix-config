{
  flake.homeModules.prismlauncher =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
    in
    {
      home.packages = lib.optional isLinux (
        pkgs.prismlauncher.overrideAttrs (old: {
          # SDL3 picks XWayland under niri (no fifo-v1), and SDL 3.4.14's XWayland relative mouse is broken (SDL#16163).
          qtWrapperArgs = old.qtWrapperArgs ++ [ "--set SDL_VIDEO_DRIVER wayland" ];
        })
      );
    };
}
