{ self, ... }:
{
  flake.nixosModules.desktopKde =
    (self.lib.mkBundle {
      nixos = [
        self.nixosModules.plasma
        {
          services.desktopManager.plasma6.enable = true;
          services.displayManager.sddm = {
            enable = true;
            wayland.enable = true;
          };

          services.libinput = {
            enable = true;
            touchpad.naturalScrolling = true;
          };

          # No gnome-keyring: a second keyring re-keys what Brave has saved in KWallet.

          # KWin has no virtual-keyboard protocol, so dictate types through ydotool here.
          programs.ydotool.enable = true;
          users.users.${self.lib.user.name}.extraGroups = [ "ydotool" ];
        }
      ];

      home = [ self.homeModules.plasma ];
    }).nixos;
}
