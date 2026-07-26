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

    # Flexoki for Discord. Was written into ~/.config by a noctalia template;
    # it lives here now like every other theme.
    #
    # Two caveats this cannot fix: the upstream theme it builds on is pulled
    # from a URL at load time, so it needs network and breaks if that URL
    # moves, and Vesktop only applies a theme once it is ticked on in its own
    # settings, which are app-managed and not declarable.
    home.file.".config/vesktop/themes/flexoki.theme.css".source = ./flexoki-discord.css;
  };
}
