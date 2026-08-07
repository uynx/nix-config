{
  flake.homeModules.media = { pkgs, ... }: {
    home.packages = with pkgs; [
      (obs-studio.override { browserSupport = false; })
      mpv
      qbittorrent
      v4l-utils
      imagemagick
      ghostscript
    ];
  };
}
