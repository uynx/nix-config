{ self, ... }:
{
  flake.nixosModules.desktopNiri =
    (self.lib.mkBundle {
      nixos = with self.nixosModules; [
        niri
        noctalia
        sddm
        screenUtils
      ];
      home = with self.homeModules; [
        niri
        noctalia
        theme
        screenUtils
        waydroid
      ];
    }).nixos;
}
