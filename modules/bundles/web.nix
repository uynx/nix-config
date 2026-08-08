{ self, ... }:
let
  bundle = self.lib.mkBundle {
    homeLinux = with self.homeModules; [
      braveOrigin
      launchers
    ];
    # Brave Origin is built from the Debian arm64 package and the launchers
    # write .desktop files, so macOS takes the cask plus the menu shortcuts.
    # Its own launchers are in `desktopMacos`: they focus through AeroSpace.
    homeDarwin = [ self.homeModules.braveShortcuts ];
    darwin = [ self.darwinModules.brave ];
  };
in
{
  # Brave Origin plus the per-profile launcher wrappers, which shell out to
  # `brave-origin` and so cannot be separated from it.
  flake.nixosModules.web = bundle.nixos;
  flake.darwinModules.web = bundle.darwin;
}
