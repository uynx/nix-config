{ self, ... }:
{
  flake.darwinModules.desktopMacos =
    (self.lib.mkBundle {
      darwin = [ self.darwinModules.sketchybar ];
      home = with self.homeModules; [
        aerospace
        launchersMacos
        sketchybar
        jankyborders
        desktoppr
        duti
      ];
    }).darwin;
}
