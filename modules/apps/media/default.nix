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
          (symlinkJoin {
            name = "obs-studio-nvenc";
            paths = [ (obs-studio.override { browserSupport = false; }) ];
            nativeBuildInputs = [ makeWrapper ];
            # obs-nvenc-test dlopens libnvidia-encode.so.1 and nothing puts the driver dir on its search path.
            postBuild = ''
              wrapProgram $out/bin/obs --suffix LD_LIBRARY_PATH : /run/opengl-driver/lib
            '';
          })
          obs-cmd
          v4l-utils
        ];
    };
}
