{
  flake.homeModules.gpg =
    { pkgs, ... }:
    {
      programs.gpg.enable = true;

      services.gpg-agent = {
        enable = true;
        # Qt to match the rest of the desktop; pinentry-gnome3 wants a GNOME
        # dbus service that is not running under niri.
        pinentry.package = pkgs.pinentry-qt;
        defaultCacheTtl = 1800;
        maxCacheTtl = 7200;
        # Left off deliberately: gnome-keyring is already the ssh agent here,
        # and two agents fighting over SSH_AUTH_SOCK breaks both.
        enableSshSupport = false;
      };
    };
}
