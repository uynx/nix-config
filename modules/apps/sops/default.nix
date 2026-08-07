{ inputs, ... }:
{
  flake.homeModules.sops =
    { config, pkgs, ... }:
    {
      imports = [ inputs.sops-nix.homeModules.sops ];

      home.packages = [ pkgs.sops ];

      sops = {
        defaultSopsFile = ../../../secrets/secrets.yaml;

        # PGP backend rather than age. Setting gnupg.home also moves the
        # activation service into graphical-session-pre.target, which is what
        # lets pinentry-qt prompt for the passphrase at login.
        gnupg.home = "${config.home.homeDirectory}/.gnupg";

        # Overwriting ~/.ssh/id_ed25519 is intended: sops-install-secrets
        # deletes whatever sits at a secret's path and symlinks the decrypted
        # copy in, so the plaintext key stops existing on disk.
        secrets.ssh-id-ed25519.path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };

      systemd.user.services.sops-nix = {
        Unit.After = [ "graphical-session.target" ];
        Install.WantedBy = pkgs.lib.mkForce [ "graphical-session.target" ];
      };
    };
}
