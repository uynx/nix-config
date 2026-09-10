{ self, ... }:
let
  bundle = self.lib.mkBundle {
    nixos = with self.nixosModules; [
      sops
      enteAuth
    ];
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
  flake.nixosModules.secrets = bundle.nixos;
  flake.darwinModules.secrets = bundle.darwin;
}
