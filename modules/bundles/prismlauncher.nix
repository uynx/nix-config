{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.prismlauncher ];
    darwin = [ self.darwinModules.prismlauncherCasks ];
  };
in
{
  flake.nixosModules.prismlauncher = bundle.nixos;
  flake.darwinModules.prismlauncher = bundle.darwin;
}
