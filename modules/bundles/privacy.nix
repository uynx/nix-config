{ self, ... }:
let
  bundle = self.lib.mkBundle {
    nixos = [ self.nixosModules.obscura ];
    homeLinux = with self.homeModules; [
      privacyBrowsers
      obscura
    ];
    darwin = with self.darwinModules; [
      privacyBrowsers
      obscura
    ];
  };
in
{
  flake.nixosModules.privacy = bundle.nixos;
  flake.darwinModules.privacy = bundle.darwin;
}
