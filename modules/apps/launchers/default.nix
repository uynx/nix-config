{
  # Mod+N / Mod+M profile launchers for niri. Split from darwin.nix rather than
  # branched: the two platforms share no line of this — different browser
  # binary, different window handling, and only Linux has a .desktop file.
  flake.homeModules.launchers =
    { pkgs, ... }:
    let
      brave = pkgs.writeShellApplication {
        name = "brave-activation";
        text = ''
          braveHome="''${XDG_CONFIG_HOME:-$HOME/.config}/BraveSoftware"

          case "''${1:-}" in
            Personal) data="$braveHome/Brave-Browser" ;;
            School)   data="$braveHome/Brave-Browser-School" ;;
            *) echo "usage: brave-activation Personal|School" >&2; exit 1 ;;
          esac
          shift

          # Strict fingerprinting is absent from brave://settings/shields
          # until this feature is enabled; it is what masks the WebGL
          # vendor/renderer string that Standard leaves untouched.
          exec brave-origin \
            --enable-features=BraveShowStrictFingerprintingMode \
            --user-data-dir="$data" \
            --profile-directory=Default \
            --disable-breakpad \
            --no-pings \
            --disable-domain-reliability \
            --disable-background-networking \
            --no-default-browser-check \
            --no-first-run \
            "$@"
        '';
      };
    in
    {
      home.packages = [ brave ];

      # Same filename shadows the packaged brave-origin.desktop, whose Exec has
      # no --user-data-dir and opens an empty third profile. home.file, not
      # xdg.desktopEntries: that is gated on xdg.enable, false here.
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
