{
  # SDDM with the astronaut theme, replacing greetd + ReGreet.
  #
  # The theme is Qt6/QML — the same stack Quickshell (and so noctalia) renders
  # with — which is why it matches the desktop and a GTK greeter never did.
  #
  # Noctalia itself still cannot do this job: it ships a LockScreen, which locks
  # an already-running session, whereas a greeter runs before any session exists.
  flake.nixosModules.sddm =
    { pkgs, lib, ... }:
    let
      # Multi-line substitution patterns live here rather than inline in the
      # postInstall: a Nix '' block strips the common leading indentation, so a
      # pattern's second line silently loses the eight spaces it must match and
      # substituteInPlace fails with a pattern-not-found error.
      # The clock is sized in PIXELS as a fraction of the panel rather than in
      # points off the base font, so it is independent of DPI and of compositor
      # scale and a headless render predicts the greeter exactly. The theme's
      # layout still measures itself in root.font.pointSize; only these two
      # labels change unit. Date is unbolded — bold reads as heavy at its size.
      #
      # Screen lives in QtQuick.Window, which Clock.qml does not import.
      importOld = "import QtQuick.Controls 2.15";
      importNew = "import QtQuick.Controls 2.15\nimport QtQuick.Window 2.15";

      # Two lines, so the date's bold is changed without touching the time's
      # identical one. Ordering matters below: '* 2' is a prefix of any '* 2.x'.
      dateOld = "font.pointSize: root.font.pointSize * 2\n        font.bold: true";
      dateNew = "font.pixelSize: Screen.height * 0.022\n        font.bold: false";
      timeOld = "font.pointSize: root.font.pointSize * 9";
      timeNew = "font.pixelSize: Screen.height * 0.055";

      # Flexoki Dark, same values as ghostty, neovim and noctalia.
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
            # Empty means "follow the actual panel". The bundled theme hardcodes
            # 1920x1080, which renders the whole greeter into a 1920x1080 box on
            # this 3024x1890 display. See the Main.qml fix below.
            ScreenWidth = "";
            ScreenHeight = "";
            # Hack is the coding font (ghostty, nvim) and looks wrong as UI
            # chrome. Cantarell is already in fonts.packages and is a UI sans.
            Font = "Cantarell";
            FontSize = "";
            HourFormat = "h:mm AP";

            # Store path, not ~/dotfiles: /home/uynx is 0700, so the greeter user
            # could never read the wallpaper ReGreet was pointed at. Shared with
            # noctalia, which scans the same directory.
            Background = "${../../wallpapers}/wallpaper.png";
            BackgroundPlaceholder = "";
            # Crop rather than stretch: the wallpaper is 1813x1080 (1.68) and the
            # panel is 1.60, so a fit would letterbox and a fill would distort.
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
          (old: {
            # Upstream typo: `Screen.ScreenWidth` does not exist, so an empty
            # ScreenWidth leaves the root Pane's width undefined and it collapses.
            # Fixing it is what lets both dimensions stay unset above, which in
            # turn makes the theme correct on any output instead of one.
            postInstall = ''
              main=$out/share/sddm/themes/sddm-astronaut-theme/Main.qml
              clock=$out/share/sddm/themes/sddm-astronaut-theme/Components/Clock.qml
              conf=$out/share/sddm/themes/sddm-astronaut-theme/Themes/hyprland_kath.conf
              chmod u+w "$main" "$clock" "$conf"
              substituteInPlace "$conf" \
                --replace-fail 'ScreenWidth="1920"' 'ScreenWidth=""' \
                --replace-fail 'ScreenHeight="1080"' 'ScreenHeight=""' \
                --replace-fail 'FontSize="12"' 'FontSize=""'
              # 85, not the theme's 80: the base font drives every field height,
              # spacing and margin in the theme, and the login inputs read a
              # little large at 80.
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
        # qtsvg / qtmultimedia / qtvirtualkeyboard / qt5compat (for QtQuick.Effects),
        # which the QML needs on its import path inside the greeter.
        extraPackages = theme.propagatedBuildInputs ++ [ pkgs.kdePackages.qt5compat ];
        settings.Theme.CursorTheme = "capitaine-cursors";
        # SDDM's own channel for handing environment to the greeter, which does
        # not inherit the service's. Belt and braces with the cache wipe in
        # preStart: either one alone is enough, and both are nearly free.
        settings.General.GreeterEnvironment = "QML_DISABLE_DISK_CACHE=1";
      };

      # SDDM resolves themes from the system profile, not from extraPackages.
      environment.systemPackages = [
        theme
        pkgs.capitaine-cursors
      ];

      # Puts niri in the session picker.
      services.displayManager.sessionPackages = [ pkgs.niri ];

      # Weston takes the lowest-numbered DRM card. Until apple-drm binds, that
      # is U-Boot's simpledrm on card0 — and binding is what tears simpledrm
      # down, so a greeter that starts first opens a card that is disappearing
      # underneath it, dies on drmModeGetResources, and SDDM logs the death as
      # a success and never retries. The screen is left blank with the console
      # cursor. Waiting for the display node means card0 is already gone and
      # weston picks the real one without being told which index it is.
      systemd.services.display-manager = {
        preStart = ''
          until [ -e /dev/dri/by-path/platform-soc:display-subsystem-card ]; do sleep 0.2; done

          # Delete the greeter's compiled-QML cache before every start. Qt only
          # reuses it when the source path and mtime match, and on NixOS both are
          # permanently fixed, so it never expires on its own and the greeter
          # redraws whichever theme it compiled first. Removing the directory is
          # the one approach that does not depend on an environment variable
          # reaching the greeter, which is a separate process that sddm-helper
          # starts with a session environment of its own.
          rm -rf /var/lib/sddm/.cache
        '';
        serviceConfig.TimeoutStartSec = "60s";

        # Qt caches compiled QML under ~/.cache/sddm-greeter-qt6/qmlcache and
        # decides the cache is still current by comparing the source file's path
        # and mtime. On NixOS neither can ever change: the greeter loads the
        # theme through /run/current-system/sw/..., which is identical in every
        # generation, and every store file's mtime is the epoch. So the cache
        # never invalidates and the greeter renders whichever QML it happened to
        # compile first, discarding every later edit — silently, with no error
        # and no fallback. Theme *config* changes still applied, because SDDM
        # reads those in C++ rather than through QML, which is what made this
        # look like the QML edits were landing somewhere unrelated.
        #
        # Compiling the theme afresh each start costs milliseconds. Do not
        # remove this without giving the greeter some other way to notice that
        # its QML changed.
        environment.QML_DISABLE_DISK_CACHE = "1";
      };

      services.gnome.gnome-keyring.enable = true;
      security.pam.services.sddm.enableGnomeKeyring = true;
    };
}
