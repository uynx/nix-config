{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.office ];
  };
in
{
  flake.nixosModules.office = bundle.nixos;
  flake.darwinModules.office = bundle.darwin;
}
