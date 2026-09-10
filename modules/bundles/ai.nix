{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.aiTools ];
    homeLinux = with self.homeModules; [
      aiToolsPinned
      dictate
    ];
    darwin = [ self.darwinModules.aiTools ];
  };
in
{
  flake.nixosModules.ai = bundle.nixos;
  flake.darwinModules.ai = bundle.darwin;
}
