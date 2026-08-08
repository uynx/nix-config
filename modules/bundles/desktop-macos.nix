{ self, ... }:
{
  # The macOS counterpart to `desktopNiri`: tiling window manager, status bar
  # and the focused-window ring. Everything below is a darwin-only program, so
  # unlike the Linux desktops this bundle has no NixOS half at all.
  flake.darwinModules.desktopMacos =
    (self.lib.mkBundle {
      darwin = [ self.darwinModules.sketchybar ];
      home = with self.homeModules; [
        aerospace
        sketchybar
        jankyborders
        desktoppr
        duti
      ];
    }).darwin;
}
