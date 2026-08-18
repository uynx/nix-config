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
      ] ++ lib.optionals isLinux [
        pkgs.bitwarden-desktop
      ];

      # Bitwarden's own "start on login" toggle writes this file with the running
      # build's store path baked in, so the next version bump plus a GC leaves an
      # autostart entry pointing at nothing. Declaring it re-resolves per rebuild.
      home.file = lib.mkIf isLinux {
        ".config/autostart/bitwarden.desktop".force = true;
        ".config/autostart/bitwarden.desktop".text = ''
          [Desktop Entry]
          Type=Application
          Name=Bitwarden
          Exec=${lib.getExe pkgs.bitwarden-desktop}
          StartupNotify=false
          Terminal=false
        '';
      };

      xdg.mimeApps = lib.mkIf isLinux {
        enable = true;
        defaultApplications."x-scheme-handler/bitwarden" = "bitwarden.desktop";
      };
    };
}
