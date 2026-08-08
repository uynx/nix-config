{ self, ... }:
let
  bundle = self.lib.mkBundle {
    home = [ self.homeModules.latex ];
  };
in
{
  # texlive scheme-full off the stable pin. Separate from `office` only because
  # it is several gigabytes and worth declining on its own line.
  flake.nixosModules.latex = bundle.nixos;
  flake.darwinModules.latex = bundle.darwin;
}
