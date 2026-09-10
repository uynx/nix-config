{ self, ... }:
{
  flake.nixosModules.desktopNiri =
    (self.lib.mkBundle {
      nixos = with self.nixosModules; [
        niri
        noctalia
        sddm
        screenUtils
        ananicy
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
