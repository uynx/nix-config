{ self, ... }:
{
  # The macOS counterpart to `desktopNiri`. Everything below is a darwin-only
  # program, so unlike the Linux desktops this bundle has no NixOS half at all.
  flake.darwinModules.desktopMacos =
    (self.lib.mkBundle {
      darwin = [ self.darwinModules.sketchybar ];
      home = with self.homeModules; [
        aerospace
        # Not `web` like on Linux: these focus through AeroSpace, so they belong
        # to the window manager rather than to the browser.
        launchersMacos
        sketchybar
        jankyborders
        desktoppr
        duti
      ];
    }).darwin;
}
