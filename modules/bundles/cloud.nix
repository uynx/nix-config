{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.rclone ];
  };
in
{
  flake.nixosModules.cloud = bundle.nixos;
  flake.darwinModules.cloud = bundle.darwin;
}
