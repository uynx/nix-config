{ self, ... }:
{
  # Chat clients. Portable.
  flake.nixosModules.comms = self.lib.mkBundle {
    home = [ self.homeModules.comms ];
  };
}
