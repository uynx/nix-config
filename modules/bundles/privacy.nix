{ self, ... }:
let
  bundle = self.lib.mkBundle {
    nixos = [ self.nixosModules.obscura ];
    homeLinux = [ self.homeModules.obscura ];
    darwin = [ self.darwinModules.obscura ];
  };
in
{
  flake.nixosModules.privacy = bundle.nixos;
  flake.darwinModules.privacy = bundle.darwin;
}
