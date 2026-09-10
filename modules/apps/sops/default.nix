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

      home.activation.deriveSshPublicKey = lib.hm.dag.entryAfter [ "sops-nix" ] ''
        privateKey=${config.home.homeDirectory}/.ssh/id_ed25519
        publicKey="$privateKey.pub"
        if [[ -e "$privateKey" && ! -e "$publicKey" ]]; then
          run ${pkgs.openssh}/bin/ssh-keygen -y -f "$privateKey" > "$publicKey"
        fi

        signers=${config.xdg.configHome}/git/allowed_signers
        if [[ -e "$publicKey" ]]; then
          run ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$signers")"
          run ${pkgs.coreutils}/bin/printf '%s %s\n' \
            "$(${pkgs.git}/bin/git config --get user.email)" "$(< "$publicKey")" > "$signers"
        fi
      '';

      sops = {
        defaultSopsFile = ../../../secrets/secrets.yaml;

        age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";

        secrets.ssh-id-ed25519.path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };

    };

  flake.nixosModules.sops = {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops = {
      defaultSopsFile = ../../../secrets/secrets.yaml;
      age.keyFile = "${self.lib.user.home}/.config/sops/age/keys.txt";
    };
  };
}
