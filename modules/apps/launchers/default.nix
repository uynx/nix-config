{
  flake.homeModules.launchers =
    { pkgs, ... }:
    let
      common = import ./_common.nix;

      brave = pkgs.writeShellApplication {
        name = "brave-activation";
        text = ''
          # Both profiles share one data dir, or Brave hides its profile button.
          case "''${1:-}" in
            Personal) profile=Default ;;
            School) profile="Profile 1" ;;
            *) echo "usage: brave-activation Personal|School" >&2; exit 1 ;;
          esac
          shift

          exec brave-origin \
            --user-data-dir="''${XDG_CONFIG_HOME:-$HOME/.config}/BraveSoftware/Brave-Browser" \
            --profile-directory="$profile" \
            --password-store=gnome-libsecret \
            ${common.hardening} \
            "$@"
        '';
      };

      # Plasma binds global shortcuts only to desktop files under share/kglobalaccel.
      shortcutEntry =
        name: profile:
        pkgs.runCommand "brave-${name}-shortcut" { } ''
          mkdir -p $out/share/applications $out/share/kglobalaccel
          printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Brave ${profile}' \
            'Icon=brave-origin' 'Exec=brave-activation ${profile}' 'NoDisplay=true' \
            >$out/share/applications/brave-${name}.desktop
          ln -s ../applications/brave-${name}.desktop $out/share/kglobalaccel/
        '';
    in
    {
      home.packages = [
        brave
        (shortcutEntry "personal" "Personal")
        (shortcutEntry "school" "School")
      ];

      plasmaShortcuts = {
        "brave-personal.desktop"._launch = "Meta+N";
        "brave-school.desktop"._launch = "Meta+M";
      };

      home.file.".local/share/applications/brave-origin.desktop".text = ''
        [Desktop Entry]
        Type=Application
        Name=Brave Origin
        GenericName=Web Browser
        Icon=brave-origin
        Exec=brave-activation Personal %U
        Terminal=false
        StartupNotify=true
        StartupWMClass=brave-origin
        Categories=Network;WebBrowser;
        MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/about;x-scheme-handler/unknown;
      '';
    };
}
