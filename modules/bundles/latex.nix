{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.latex ];
  };
in
{
  flake.nixosModules.latex = bundle.nixos;
  flake.darwinModules.latex = bundle.darwin;
}
