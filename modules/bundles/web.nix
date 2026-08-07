{ self, ... }:
{
  # Brave Origin plus the per-profile launcher wrappers, which shell out to
  # `brave-origin` and so cannot be separated from it. Portable.
  flake.nixosModules.web = self.lib.mkBundle {
    home = with self.homeModules; [
      braveOrigin
      launchers
    ];
  };
}
