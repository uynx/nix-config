{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = with self.homeModules; [
      sops
      gpg
      passwords
    ];
    darwin = [ self.darwinModules.passwordsCasks ];
  };
in
{
  # Everything that holds or unlocks a credential: the sops store, the GPG agent
  # that decrypts it, and the password managers. Portable, but each machine needs
  # its own `secrets/secrets.yaml` and its own key in `.sops.yaml` — the file
  # here is encrypted to this machine's key only.
  flake.nixosModules.secrets = bundle.nixos;
  flake.darwinModules.secrets = bundle.darwin;
}
