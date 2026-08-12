{ self, ... }:
{
  flake.nixosModules.core = { pkgs, ... }: {
    imports = with self.nixosModules; [
      nixSettings
      locale
      networking
      security
      audio
      bluetooth
      fonts
      user
      nixLd
      # user.nix makes fish the login shell, so the overlay that points
      # pkgs.fish at the wrapped build has to be in reach of every host.
      fish
    ];

    # Where every tool that has not been told otherwise looks for the config:
    # `nixos-rebuild` with no `--flake`, and every piece of documentation. A
    # string rather than a path literal, so the working copy is linked instead
    # of copied into the store. Here rather than in `nixSettings` because the
    # installer ISO takes that module and has no home directory to point at.
    environment.etc.nixos.source = "${self.lib.user.home}/nixos-config";

    environment.systemPackages = with pkgs; [
      git
      vim
      wget
      curl
      brightnessctl

      # A generic `pinentry` on PATH, so any GNUPGHOME without its own
      # gpg-agent.conf (a scratch keyring, a container, `sudo -H gpg`) still
      # finds a prompt instead of failing "No pinentry". Doesn't touch the
      # real ~/.gnupg agent, which pins pinentry-qt by exact store path.
      pinentry-all
    ];

    system.stateVersion = "26.05";
  };
}
