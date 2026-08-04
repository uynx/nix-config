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

    # Two things this cannot fix: it @imports an upstream theme over the network
    # at load time, and Vesktop only applies it once ticked on in its own
    # app-managed settings.
    home.file.".config/vesktop/themes/flexoki.theme.css".source = ./flexoki-discord.css;
  };
}
