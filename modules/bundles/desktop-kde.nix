{ self, lib, ... }:
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
        # Off entirely so gnome-keyring is the only secret store and KWallet's first-use wizard never opens.
        {
          programs.plasma.configFile.kwalletrc = {
            "org.freedesktop.secrets".apiEnabled = false;
            Wallet.Enabled = false;
            Wallet."First Use" = false;
          };
        }
        {
          plasmaPinned = [
            "brave-origin.desktop"
            "com.mitchellh.ghostty.desktop"
            "org.kde.dolphin.desktop"
          ];
          plasmaWallpaper = ../wallpapers/wallpaper.png;
          plasmaSnapshotDir = "nix-config/kde-snapshots";
          programs.plasma.workspace.lookAndFeel = "org.kde.breezedark.desktop";
          programs.plasma.powerdevil = lib.genAttrs [ "AC" "battery" "lowBattery" ] (_: {
            autoSuspend.action = "nothing";
            turnOffDisplay.idleTimeout = 180;
            whenLaptopLidClosed = "turnOffScreen";
          });
          programs.plasma.shortcuts = {
            ksmserver."Lock Session" = [
              "Meta+Ctrl+Q"
              "Screensaver"
            ];
            kwin."Window Close" = [
              "Meta+Q"
              "Alt+F4"
            ];
            kwin."Window Maximize" = [
              "Meta+F"
              "Meta+PgUp"
            ];
            kwin."Window Fullscreen" = "Meta+Shift+F";
            plasmashell."manage activities" = [ ];
            "services/org.kde.kscreen.desktop".ShowOSD = "Display";
            "services/com.mitchellh.ghostty.desktop"._launch = [
              "Meta+P"
              "Ctrl+Alt+T"
            ];
          };
        }
      ];
    }).nixos;
}
