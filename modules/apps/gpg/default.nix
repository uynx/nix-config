{
  flake.homeModules.gpg =
    { pkgs, ... }:
    {
      programs.gpg.enable = true;

      services.gpg-agent = {
        enable = true;
        # pinentry-gnome3 wants a GNOME dbus service that niri does not run.
        pinentry.package = pkgs.pinentry-qt;
        defaultCacheTtl = 1800;
        maxCacheTtl = 7200;
        # gnome-keyring is already the ssh agent; two agents fighting over
        # SSH_AUTH_SOCK breaks both.
        enableSshSupport = false;
      };
    };
}
