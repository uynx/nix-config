{
  flake.homeModules.passwords =
    {
      pkgs,
      lib,
      ...
    }:
    let
      inherit (pkgs.stdenv.hostPlatform) isLinux;
    in
    {
      home.packages = [
        pkgs.bitwarden-cli
        pkgs.bitwarden-desktop
      ];

      home.file = lib.mkIf isLinux {
        ".local/share/keyrings/default".force = true;
        ".local/share/keyrings/default".text = "login";

        ".config/autostart/bitwarden.desktop".force = true;
        ".config/autostart/bitwarden.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Bitwarden
          Hidden=true
        '';
      };

      xdg.mimeApps = lib.mkIf isLinux {
        enable = true;
        defaultApplications."x-scheme-handler/bitwarden" = "bitwarden.desktop";
      };
    };
}
