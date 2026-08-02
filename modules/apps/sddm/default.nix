{
  # SDDM with the astronaut theme, replacing greetd + ReGreet.
  #
  # The theme is Qt6/QML — the same stack Quickshell (and so noctalia) renders
  # with — which is why it matches the desktop and a GTK greeter never did.
  #
  # Noctalia itself still cannot do this job: it ships a LockScreen, which locks
  # an already-running session, whereas a greeter runs before any session exists.
  flake.nixosModules.sddm =
    { pkgs, ... }:
    let
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
              substituteInPlace "$main" \
                --replace-fail 'Screen.ScreenWidth' 'Screen.width' \
                --replace-fail 'parseInt(height / 80)' 'parseInt(height / 70)'
              # The clock is sized in PIXELS as a fraction of the panel, not in
              # points off the base font. Points are scaled by the display's
              # DPI, so a multiplier that looked right in a preview rendered
              # very differently on the real greeter — and Qt reports this panel
              # as 945 tall inside the niri session (eDP-1 is scale 2.0) versus
              # the full 1890 under the greeter's unscaled Weston, so a preview
              # taken from a logged-in session showed every font at half size.
              # Keying off Screen.height in pixels removes both variables: 5.5%
              # = 104px time, 2.2% = 42px date, identical in preview and greeter.
              #
              # Screen needs QtQuick.Window; Clock.qml does not import it.
              #
              # This also retires the ordering trap the old point-based rules
              # had: neither replacement now emits the text the other matches.
              #
              # The date rule spans two lines so it can unbold that label alone
              # without a second pass — the time label's bold line is identical,
              # and only the preceding size line tells them apart. Bold reads as
              # chunky at the date's size; set it back to true to undo.
              substituteInPlace "$clock" \
                --replace-fail 'import QtQuick.Controls 2.15' 'import QtQuick.Controls 2.15
import QtQuick.Window 2.15' \
                --replace-fail 'font.pointSize: root.font.pointSize * 9' 'font.pixelSize: Screen.height * 0.055' \
                --replace-fail 'font.pointSize: root.font.pointSize * 2
        font.bold: true' 'font.pixelSize: Screen.height * 0.022
        font.bold: false'
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
        '';
        serviceConfig.TimeoutStartSec = "60s";
      };

      services.gnome.gnome-keyring.enable = true;
      security.pam.services.sddm.enableGnomeKeyring = true;
    };
}
