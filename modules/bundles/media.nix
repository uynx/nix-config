{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.media ];
    darwin = [ self.darwinModules.mediaCasks ];
  };
in
{
  flake.nixosModules.media = bundle.nixos;
  flake.darwinModules.media = bundle.darwin;
}
