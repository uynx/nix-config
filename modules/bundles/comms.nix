{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.comms ];
    homeLinux = [ self.homeModules.rustdesk ];
    darwin = [ self.darwinModules.rustdesk ];
  };
in
{
  flake.nixosModules.comms = bundle.nixos;
  flake.darwinModules.comms = bundle.darwin;
}
