{
  flake.nixosModules.sddm =
    { pkgs, lib, ... }:
    let
      # Plain strings, not '' blocks: those strip leading indentation and
      # silently break a multi-line match.
      importOld = "import QtQuick.Controls 2.15";
      importNew = "import QtQuick.Controls 2.15\nimport QtQuick.Window 2.15";

      dateOld = "font.pointSize: root.font.pointSize * 2\n        font.bold: true";
      dateNew = "font.pixelSize: Screen.height * 0.022\n        font.bold: false";
      timeOld = "font.pointSize: root.font.pointSize * 9";
      timeNew = "font.pixelSize: Screen.height * 0.055";

      bg = "#100f0f";
      fg = "#cecdc3";
      field = "#403e3c";
      gray = "#878580";
      amber = "#d0a215";
      red = "#d14d41";

      theme =
        (pkgs.sddm-astronaut.override {
          embeddedTheme = "hyprland_kath";
          # Emitted as Themes/hyprland_kath.conf.user, which SDDM merges over the
          # bundled .conf — only the keys below change.
          themeConfig = {
            # Empty means "follow the actual panel"; the theme hardcodes
            # 1920x1080. Needs the Main.qml fix below to work.
            ScreenWidth = "";
            ScreenHeight = "";
            # Hack is the coding font and looks wrong as UI chrome.
            Font = "Cantarell";
            FontSize = "";
            HourFormat = "h:mm AP";

            # Store path, not ~/dotfiles: /home/uynx is 0700 and the greeter
            # runs as its own user.
            Background = "${../../wallpapers}/wallpaper.png";
            BackgroundPlaceholder = "";
            # Wallpaper is 1.68, panel is 1.60: a fit letterboxes, a fill distorts.
            CropBackground = "true";
            DimBackground = "0.15";

            HeaderTextColor = fg;
            DateTextColor = fg;
            TimeTextColor = amber;

            FormBackgroundColor = bg;
            BackgroundColor = bg;
            DimBackgroundColor = bg;

            LoginFieldBackgroundColor = field;
            PasswordFieldBackgroundColor = field;
            LoginFieldTextColor = fg;
            PasswordFieldTextColor = fg;
            UserIconColor = gray;
            PasswordIconColor = gray;

            PlaceholderTextColor = gray;
            WarningColor = red;

            LoginButtonTextColor = bg;
            LoginButtonBackgroundColor = amber;
            SystemButtonsIconsColor = fg;
            SessionButtonTextColor = fg;
            VirtualKeyboardButtonTextColor = fg;

            DropdownTextColor = fg;
            DropdownBackgroundColor = bg;
            DropdownSelectedBackgroundColor = field;

            HighlightTextColor = bg;
            HighlightBackgroundColor = amber;
            HighlightBorderColor = "transparent";

            HoverUserIconColor = amber;
            HoverPasswordIconColor = amber;
            HoverSystemButtonsIconsColor = amber;
            HoverSessionButtonTextColor = amber;
            HoverVirtualKeyboardButtonTextColor = amber;

            HideSystemButtons = "false";
          };
        }).overrideAttrs
          (_: {
            # Upstream typo: Screen.ScreenWidth does not exist, so an empty
            # ScreenWidth collapses the root Pane. Fixing it is what lets both
            # dimensions stay unset and the theme fit any output.
            postInstall = ''
              main=$out/share/sddm/themes/sddm-astronaut-theme/Main.qml
              clock=$out/share/sddm/themes/sddm-astronaut-theme/Components/Clock.qml
              conf=$out/share/sddm/themes/sddm-astronaut-theme/Themes/hyprland_kath.conf
              chmod u+w "$main" "$clock" "$conf"
              substituteInPlace "$conf" \
                --replace-fail 'ScreenWidth="1920"' 'ScreenWidth=""' \
                --replace-fail 'ScreenHeight="1080"' 'ScreenHeight=""' \
                --replace-fail 'FontSize="12"' 'FontSize=""'
              # Divisor drives every field height, spacing and margin, not just text.
              substituteInPlace "$main" \
                --replace-fail 'Screen.ScreenWidth' 'Screen.width' \
                --replace-fail 'parseInt(height / 80)' 'parseInt(height / 85)'

              substituteInPlace "$clock" \
                --replace-fail ${lib.escapeShellArg importOld} ${lib.escapeShellArg importNew} \
                --replace-fail ${lib.escapeShellArg dateOld} ${lib.escapeShellArg dateNew} \
                --replace-fail ${lib.escapeShellArg timeOld} ${lib.escapeShellArg timeNew}
            '';
          });
    in
    {
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
        package = pkgs.kdePackages.sddm;
        theme = "sddm-astronaut-theme";
        # qt5compat supplies QtQuick.Effects, which the theme QML imports.
        extraPackages = theme.propagatedBuildInputs ++ [ pkgs.kdePackages.qt5compat ];
        settings.Theme.CursorTheme = "capitaine-cursors";
        # The greeter does not inherit the service's environment.
        settings.General.GreeterEnvironment = "QML_DISABLE_DISK_CACHE=1";
      };

      # SDDM resolves themes from the system profile, not from extraPackages.
      environment.systemPackages = [
        theme
        pkgs.capitaine-cursors
      ];

      # Puts niri in the session picker.
      services.displayManager.sessionPackages = [ pkgs.niri ];

      # Weston grabs the lowest-numbered DRM card, which before apple-drm binds
      # is U-Boot's simpledrm on card0 — the node that binding tears down. The
      # greeter then dies on drmModeGetResources and SDDM logs it as success.
      systemd.services.display-manager = {
        preStart = ''
          until [ -e /dev/dri/by-path/platform-soc:display-subsystem-card ]; do sleep 0.2; done

          # Qt reuses compiled QML when source path and mtime match, and on
          # NixOS both are frozen — so every theme edit is silently ignored.
          rm -rf /var/lib/sddm/.cache
        '';
        serviceConfig.TimeoutStartSec = "60s";
        environment.QML_DISABLE_DISK_CACHE = "1";
      };

      services.gnome.gnome-keyring.enable = true;
      security.pam.services.sddm.enableGnomeKeyring = true;
    };
}
