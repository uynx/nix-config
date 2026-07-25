{
  flake.homeModules.media = { pkgs, ... }: {
    home.packages = with pkgs; [
      obs-studio
      vesktop
      mpv
      v4l-utils
      imagemagick
      ghostscript
    ];
  };
}
