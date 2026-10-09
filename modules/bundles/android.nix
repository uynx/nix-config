{ self, ... }:
{
  flake.nixosModules.android = (self.lib.mkBundle { home = [ self.homeModules.waydroid ]; }).nixos;
}
