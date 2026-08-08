{ self, ... }:
{
  # Brave Origin plus the per-profile launcher wrappers, which shell out to
  # `brave-origin` and so cannot be separated from it.
  flake.nixosModules.web =
    (self.lib.mkBundle {
      home = with self.homeModules; [
        braveOrigin
        launchers
      ];
    }).nixos;

  # Brave Origin is built here from the Debian arm64 package and the launchers
  # write .desktop files, so macOS takes the cask plus the menu shortcuts.
  flake.darwinModules.web =
    (self.lib.mkBundle {
      darwin = [ self.darwinModules.webCasks ];
      home = [ self.homeModules.braveShortcuts ];
    }).darwin;
}
