{ inputs, self, ... }:
{
  flake.homeModules.sops =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.sops-nix.homeModules.sops ];

      home.packages = [
        pkgs.sops
        pkgs.rage
      ];

      # Git's SSH commit signing (modules/apps/git) needs id_ed25519.pub, but
      # sops-nix only ever restores the private half. Derived here rather than
      # committed: it's cheap to regenerate and doesn't need to be a secret.
      # Guarded on the private key existing because sops-nix's own darwin
      # activation (below in its module) only *triggers* the launchd agent
      # that decrypts secrets — it doesn't wait for it — so on a fresh
      # machine's first activation the private key may not be written yet.
      # Skipping is safe: every activation retries, and once the key lands
      # once this never has to run again.
      home.activation.deriveSshPublicKey = lib.hm.dag.entryAfter [ "sops-nix" ] ''
        privateKey=${config.home.homeDirectory}/.ssh/id_ed25519
        publicKey="$privateKey.pub"
        if [[ -e "$privateKey" && ! -e "$publicKey" ]]; then
          run ${pkgs.openssh}/bin/ssh-keygen -y -f "$privateKey" > "$publicKey"
        fi

        # Same reason as the public half: signing needs neither of these, but
        # without allowed_signers every local verification fails and `%G?`
        # reports N on a commit that is in fact signed. The principal is read
        # back out of git rather than restated, so it cannot drift from
        # modules/apps/git.
        signers=${config.xdg.configHome}/git/allowed_signers
        if [[ -e "$publicKey" ]]; then
          run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$signers")"
          run ${pkgs.coreutils}/bin/printf '%s %s\n' \
            "$(${pkgs.git}/bin/git config --get user.email)" "$(< "$publicKey")" > "$signers"
        fi
      '';

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

  # System tier, Linux only. NetworkManager reads the eduroam credentials as
  # root at unit start, before any user service could have decrypted them, so
  # the home tier above cannot serve them.
  #
  # Keyed to the same age identity as the home tier rather than an SSH host key,
  # which is sops-nix's usual system bootstrap: this machine runs no sshd, so
  # /etc/ssh/ssh_host_* does not exist, and enabling one purely to mint a key
  # would reopen a service the firewall audit deliberately closed. One identity,
  # one .sops.yaml entry, one manual restore covering both tiers.
  #
  # A secret declared here but absent from secrets.yaml fails activation, so add
  # the value before the rebuild that references it.
  flake.nixosModules.sops = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops = {
      defaultSopsFile = ../../../secrets/secrets.yaml;
      age.keyFile = "${self.lib.user.home}/.config/sops/age/keys.txt";
    };
  };
}
