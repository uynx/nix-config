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
      ]
      ++ lib.optionals isLinux [
        pkgs.bitwarden-desktop
      ];

      # Masked, not deleted: Bitwarden's own "start on login" toggle rewrites this
      # file whenever it is on, so simply removing the declaration lets the app put
      # it back. Hidden=true is the XDG spec's own "ignore this entry", and force
      # keeps Home Manager owning the path.
      home.file = lib.mkIf isLinux {
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
