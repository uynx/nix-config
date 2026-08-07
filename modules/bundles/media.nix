{ self, ... }:
{
  # Playback, capture and image tooling. Portable.
  flake.nixosModules.media = self.lib.mkBundle {
    home = [ self.homeModules.media ];
  };
}
