{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.roblox ];
    darwin = [ self.darwinModules.robloxCasks ];
  };
in
{
  flake.nixosModules.roblox = bundle.nixos;
  flake.darwinModules.roblox = bundle.darwin;
}
