{
  flake.homeModules.gpg =
    { pkgs, ... }:
    {
      programs.gpg.enable = true;

      services.gpg-agent = {
        enable = true;
        # pinentry-gnome3 wants a GNOME dbus service that niri does not run.
        # pinentry-qt is Linux-only, and this module reaches darwin too.
        pinentry.package =
          if pkgs.stdenv.hostPlatform.isDarwin then pkgs.pinentry_mac else pkgs.pinentry-qt;
        defaultCacheTtl = 1800;
        maxCacheTtl = 7200;
        # enableSshSupport stays at its default false: gcr-ssh-agent already
        # owns SSH_AUTH_SOCK (it spawns plain ssh-agent on
        # /run/user/1000/gcr/ssh) and two agents fighting over it breaks both.
        # Not gnome-keyring — modern builds dropped their SSH component.
      };
    };
}
