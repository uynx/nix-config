{
  flake.homeModules.media =
    { pkgs, lib, ... }:
    {
      home.packages =
        with pkgs;
        [
          mpv
          qbittorrent
          imagemagick
          ghostscript
        ]
        # OBS' nixpkgs build and the V4L tools are both Linux-only; the macOS
        # half of the bundle casks OBS instead.
        ++ lib.optionals stdenv.hostPlatform.isLinux [
          (obs-studio.override { browserSupport = false; })
          obs-cmd
          v4l-utils
        ];
    };
}
