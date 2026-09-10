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
        ++ lib.optionals stdenv.hostPlatform.isLinux [
          (obs-studio.override { browserSupport = false; })
          obs-cmd
          v4l-utils
        ];
    };
}
