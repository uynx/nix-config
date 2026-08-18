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
        # PAM's enableGnomeKeyring only ever unlocks the keyring named `login` —
        # that name is hardcoded, not "whatever the default is". This pointed at
        # `Default_Keyring`, so every session gcr-prompter asked for it by hand.
        # force, because the live file is real rather than a symlink.
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
