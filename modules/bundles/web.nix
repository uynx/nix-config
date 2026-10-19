{ self, ... }:
let
  bundle = self.lib.mkBundle {
    homeLinux = with self.homeModules; [
      braveOrigin
      firefox
      launchers
      ungoogledChromium
    ];
    homeDarwin = [ self.homeModules.braveShortcuts ];
    darwin = [ self.darwinModules.brave ];
  };
in
{
  flake.nixosModules.web = bundle.nixos;
  flake.darwinModules.web = bundle.darwin;
}
