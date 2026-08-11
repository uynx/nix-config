{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = with self.homeModules; [
      sops
      passwords
    ];
  };
in
{
  # Each machine needs its own `secrets/secrets.yaml` and its own key in
  # `.sops.yaml` — the file here is encrypted to this machine's key only.
  flake.nixosModules.secrets = bundle.nixos;
  flake.darwinModules.secrets = bundle.darwin;
}
