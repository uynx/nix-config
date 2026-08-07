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
        # gcr-ssh-agent already owns SSH_AUTH_SOCK (it spawns plain ssh-agent on
        # /run/user/1000/gcr/ssh); two agents fighting over the variable breaks
        # both. Not gnome-keyring — modern builds dropped their SSH component.
        enableSshSupport = false;
      };
    };
}
