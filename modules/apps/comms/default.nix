{
  flake.homeModules.comms =
    { pkgs, lib, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      # Separate packages rather than one built twice: the Linux WhatsApp is an
      # Electron wrapper, the darwin one repackages the official app.
      home.packages = [
        (if isDarwin then pkgs.whatsapp-for-mac else pkgs.whatsapp-electron)
      ]
      ++ lib.optional (!isDarwin) pkgs.vesktop;

      # Two things this cannot fix: it @imports an upstream theme over the network
      # at load time, and Vesktop only applies it once ticked on in its own
      # app-managed settings.
      home.file = lib.mkIf (!isDarwin) {
        ".config/vesktop/themes/flexoki.theme.css".source = ./flexoki-discord.css;
      };
    };
}
