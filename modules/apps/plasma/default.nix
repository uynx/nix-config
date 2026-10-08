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
      options.plasmaPinned = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "firefox.desktop" ];
        description = ''
          Desktop file IDs pinned to the taskbar, in order. Re-applied at every
          Plasma login, so pins made by hand do not survive a login.
        '';
      };

      options.plasmaShortcuts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.str);
        default = { };
        example = {
          "dictate.desktop"._launch = "Meta+Shift+D";
        };
        description = ''
          Global shortcuts written into kglobalshortcutsrc, keyed by desktop
          file and then by the service action (`_launch` is "run it").
        '';
      };
    };

  flake.homeModules.plasma =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      writes = lib.concatLists (
        lib.mapAttrsToList (
          desktop:
          lib.mapAttrsToList (
            action: keys: ''
              $DRY_RUN_CMD $kw --file kglobalshortcutsrc \
                --group services --group ${lib.escapeShellArg desktop} \
                --key ${lib.escapeShellArg action} ${lib.escapeShellArg keys}''
          )
        ) config.plasmaShortcuts
      );
      pinJs = pkgs.writeText "plasma-pin.js" (
        builtins.replaceStrings [ "@launchers@" ] [ (builtins.toJSON config.plasmaPinned) ] (
          builtins.readFile ./pin.js
        )
      );
    in
    {
      # Without a user-profile copy the screenshot shortcut never fires.
      home.packages = [ pkgs.kdePackages.spectacle ];

      plasmaShortcuts."org.kde.spectacle.desktop" = {
        RectangularRegionScreenShot = "Meta+Shift+S";
        _launch = "Print";
      };

      xdg.configFile."kcminputrc".text = ''
        [Mouse]
        cursorTheme=breeze_cursors
        cursorSize=48
      '';

      home.pointerCursor = {
        enable = true;
        name = "breeze_cursors";
        package = pkgs.kdePackages.breeze;
        size = 48;
        gtk.enable = true;
        x11.enable = true;
      };

      home.activation.plasmaShortcuts = lib.mkIf (writes != [ ]) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          kw=${pkgs.kdePackages.kconfig}/bin/kwriteconfig6
          ${lib.concatStringsSep "\n" writes}
          $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user try-restart plasma-kglobalaccel.service || true
        ''
      );

      # Pins by desktop ID, never by /nix/store path, which dies on the next reb.
      systemd.user.services.plasma-pinned = lib.mkIf (config.plasmaPinned != [ ]) {
        Unit = {
          Description = "Pin the declared launchers to the Plasma taskbar";
          After = [ "plasma-plasmashell.service" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "plasma-pinned" ''
            script=$(${pkgs.coreutils}/bin/cat ${pinJs})
            for _ in $(${pkgs.coreutils}/bin/seq 30); do
              out=$(${pkgs.systemd}/bin/busctl --user call org.kde.plasmashell /PlasmaShell \
                org.kde.PlasmaShell evaluateScript s "$script" 2>/dev/null || true)
              case $out in
                's "'[1-9]*) exit 0 ;;
              esac
              ${pkgs.coreutils}/bin/sleep 2
            done
            echo "no Plasma task manager answered" >&2
            exit 1
          '';
        };
        Install.WantedBy = [ "plasma-plasmashell.service" ];
      };
    };
}
