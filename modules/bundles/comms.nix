{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.comms ];
    homeLinux = with self.homeModules; [
      rustdesk
      simplex
    ];
    darwin = [ self.darwinModules.rustdesk ];
  };
in
{
  flake.nixosModules.comms = bundle.nixos;
  flake.darwinModules.comms = bundle.darwin;
}
