{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.office ];
  };
in
{
  # Notes and the office suite. Portable, and the bundle the family machines
  # actually want.
  flake.nixosModules.office = bundle.nixos;
  flake.darwinModules.office = bundle.darwin;
}
