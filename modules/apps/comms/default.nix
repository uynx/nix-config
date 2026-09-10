{
  flake.homeModules.comms =
    { pkgs, lib, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;
    in
    {
      home.packages = [
        (if isDarwin then pkgs.whatsapp-for-mac else pkgs.whatsapp-electron)
      ]
      ++ lib.optional (!isDarwin) pkgs.vesktop;

      home.file = lib.mkIf (!isDarwin) {
        ".config/vesktop/themes/flexoki.theme.css".source = ./flexoki-discord.css;
      };

      xdg.mimeApps = lib.mkIf (!isDarwin) {
        enable = true;
        defaultApplications."x-scheme-handler/discord" = "vesktop.desktop";
      };
    };
}
