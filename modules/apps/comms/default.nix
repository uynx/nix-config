{
  flake.homeModules.comms = { pkgs, ... }: {
    home.packages = with pkgs; [
      vesktop
      whatsapp-electron
    ];

    # Two things this cannot fix: it @imports an upstream theme over the network
    # at load time, and Vesktop only applies it once ticked on in its own
    # app-managed settings.
    home.file.".config/vesktop/themes/flexoki.theme.css".source = ./flexoki-discord.css;
  };
}
