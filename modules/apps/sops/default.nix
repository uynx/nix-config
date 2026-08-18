{ inputs, ... }:
{
  flake.homeModules.sops =
    { config, pkgs, ... }:
    {
      imports = [ inputs.sops-nix.homeModules.sops ];

      home.packages = [
        pkgs.sops
        pkgs.rage
      ];

      sops = {
        defaultSopsFile = ../../../secrets/secrets.yaml;

        # An unencrypted age identity, so decryption needs no passphrase and no
        # prompt: with gnupg.home unset the upstream unit installs into
        # default.target instead of graphical-session-pre.target, and secrets
        # land before anything graphical starts.
        #
        # generateKey stays at its default false on purpose — true would let a
        # fresh machine mint its own key and "succeed" while decrypting nothing.
        # Restore the real one first:
        #   bw get notes 'sops age key' | install -Dm600 /dev/stdin ~/.config/sops/age/keys.txt
        age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";

        # Overwriting ~/.ssh/id_ed25519 is intended: sops-install-secrets
        # deletes whatever sits at a secret's path and symlinks the decrypted
        # copy in, so the plaintext key stops existing on disk.
        secrets.ssh-id-ed25519.path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };

    };
}
