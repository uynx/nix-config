{ self, ... }:
{
  # Notes and the office suite. Portable, and the bundle the family machines
  # actually want.
  flake.nixosModules.office = self.lib.mkBundle {
    home = [ self.homeModules.office ];
  };
}
