{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.comms ];
  };
in
{
  flake.nixosModules.comms = bundle.nixos;
  flake.darwinModules.comms = bundle.darwin;
}
