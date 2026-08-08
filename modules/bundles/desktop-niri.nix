{ self, ... }:
{
  # The whole desktop: compositor, greeter, shell/bar, GTK theme and the
  # on-screen utilities. Swapping this one line for `desktopKde` changes the
  # entire graphical environment — that is the reason the greeter and the theme
  # live in here rather than in `system/`, since both are choices a different
  # desktop would make differently.
  flake.nixosModules.desktopNiri =
    (self.lib.mkBundle {
      nixos = with self.nixosModules; [
        niri
        sddm
        screenUtils
      ];
      home = with self.homeModules; [
        noctalia
        theme
        screenUtils
        # The `android` launcher only works inside a niri session — it sizes the
        # guest from `niri msg` — so it belongs to the desktop, not to `shell`.
        waydroid
      ];
    }).nixos;
}
