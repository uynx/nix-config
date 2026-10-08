{ inputs, ... }:
{
  # Peer.Ping succeeds while the panel is frozen: only a QML eval detects the hang, only SIGKILL recovers.
  flake.nixosModules.plasma =
    { pkgs, ... }:
    let
      watchdog = pkgs.writeShellScript "plasmashell-watchdog" ''
        set -eu
        if ${pkgs.coreutils}/bin/timeout 5s ${pkgs.systemd}/bin/busctl --user \
          call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s '1' \
          >/dev/null 2>&1
        then
          exit 0
        fi
        ${pkgs.systemd}/bin/systemctl --user kill -s KILL plasma-plasmashell.service || true
        ${pkgs.systemd}/bin/systemctl --user reset-failed plasma-plasmashell.service || true
        ${pkgs.systemd}/bin/systemctl --user start plasma-plasmashell.service || true
      '';
    in
    {
      systemd.user.services.plasmashell-watchdog = {
        description = "Recover a hung Plasma panel";
        after = [ "plasma-plasmashell.service" ];
        partOf = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = watchdog;
        };
      };
      systemd.user.timers.plasmashell-watchdog = {
        description = "Ping plasmashell and recover if hung";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        timerConfig = {
          OnStartupSec = "90s";
          OnUnitActiveSec = "90s";
          AccuracySec = "15s";
          Unit = "plasmashell-watchdog.service";
        };
      };
    };

  flake.homeModules.plasmaOptions =
    { lib, ... }:
    {
      imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

      options.plasmaPinned = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "firefox.desktop" ];
        description = "Desktop file IDs pinned to the taskbar, in order.";
      };

      options.plasmaWallpaper = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Image for the desktop and the lock screen.";
      };
    };

  flake.homeModules.plasma =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      # Without a user-profile copy the screenshot shortcut never fires.
      home.packages = [ pkgs.kdePackages.spectacle ];

      programs.plasma = {
        enable = true;

        workspace = {
          cursor = {
            theme = "breeze_cursors";
            size = 48;
          };
          wallpaper = config.plasmaWallpaper;
        };
        kscreenlocker.appearance.wallpaper = config.plasmaWallpaper;

        shortcuts."services/org.kde.spectacle.desktop" = {
          RectangularRegionScreenShot = "Meta+Shift+S";
          _launch = "Print";
        };

        # Plasma 6's default bottom panel, with the host's pins in the task manager.
        panels = lib.mkIf (config.plasmaPinned != [ ]) [
          {
            location = "bottom";
            floating = true;
            widgets = [
              "org.kde.plasma.kickoff"
              "org.kde.plasma.pager"
              { iconTasks.launchers = map (id: "applications:${id}") config.plasmaPinned; }
              "org.kde.plasma.marginsseparator"
              "org.kde.plasma.systemtray"
              "org.kde.plasma.digitalclock"
              "org.kde.plasma.showdesktop"
            ];
          }
        ];
      };

      home.pointerCursor = {
        enable = true;
        name = "breeze_cursors";
        package = pkgs.kdePackages.breeze;
        size = 48;
        gtk.enable = true;
        x11.enable = true;
      };
    };
}
