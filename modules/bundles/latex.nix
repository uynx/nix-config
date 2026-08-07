{ self, ... }:
{
  # texlive scheme-full off the stable pin. Separate from `office` only because
  # it is several gigabytes and worth declining on its own line.
  flake.nixosModules.latex = self.lib.mkBundle {
    home = [ self.homeModules.latex ];
  };
}
