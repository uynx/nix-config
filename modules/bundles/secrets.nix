{ self, ... }:
let
  bundle = self.lib.mkBundle {
    # Linux only: the system tier exists for secrets root needs at unit start.
    # Darwin has no such consumer and keeps the home tier alone.
    nixos = [ self.nixosModules.sops ];
    home = with self.homeModules; [
      sops
      passwords
      enteAuth
    ];
    darwin = with self.darwinModules; [
      enteAuth
    ];
  };
in
{
  # Each machine needs its own `secrets/secrets.yaml` and its own key in
  # `.sops.yaml` — the file here is encrypted to this machine's key only.
  flake.nixosModules.secrets = bundle.nixos;
  flake.darwinModules.secrets = bundle.darwin;
}
