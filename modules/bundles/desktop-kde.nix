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

          # Brave's key lives in gnome-keyring from niri; KWallet would mint a second key and strand every login.
          services.gnome.gnome-keyring.enable = true;
          security.pam.services.sddm.enableGnomeKeyring = true;

          # KWin has no virtual-keyboard protocol, so dictate types through ydotool here.
          programs.ydotool.enable = true;
          users.users.${self.lib.user.name}.extraGroups = [ "ydotool" ];
        }
      ];

      home = [
        self.homeModules.plasma
        (
          { pkgs, lib, ... }:
          {
            # Leaves org.freedesktop.secrets to gnome-keyring.
            home.activation.kwalletSecretsOff = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              $DRY_RUN_CMD ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwalletrc \
                --group org.freedesktop.secrets --key apiEnabled false
            '';
          }
        )
      ];
    }).nixos;
}
