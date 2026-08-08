{
  # Mod+N / Mod+M browser launchers on both platforms, plus Mod+P on macOS.
  # The macOS ones focus an existing window in the focused workspace before
  # spawning anything — niri has no equivalent because it spawns per output.
  flake.homeModules.launchers =
    { pkgs, lib, ... }:
    let
      inherit (pkgs.stdenv.hostPlatform) isDarwin;

      # AeroSpace runs exec-and-forget under /bin/bash, whose PATH has neither
      # profile on it.
      aeroPath = ''
        me=$(id -un)
        export PATH="/etc/profiles/per-user/$me/bin:/run/current-system/sw/bin:$PATH"
      '';

      braveLinux = pkgs.writeShellApplication {
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

      braveDarwin = pkgs.writeShellApplication {
        name = "brave-activation";
        text = ''
          ${aeroPath}
          braveHome="$HOME/Library/Application Support/BraveSoftware"

          name=''${1:-}
          case "$name" in
            Personal) data="$braveHome/Brave-Browser" ;;
            School)   data="$braveHome/Brave-Browser-School" ;;
            *) echo "usage: brave-activation Personal|School" >&2; exit 1 ;;
          esac
          shift

          ws=$(aerospace list-workspaces --focused)
          id=$(aerospace list-windows --workspace "$ws" --format '%{window-id}|%{window-title}' 2>/dev/null |
            awk -F'|' -v s="Brave - $name" '$2 ~ s"$" { print $1; exit }' || true)
          if [ -n "$id" ]; then
            exec aerospace focus --window-id "$id"
          fi

          # aerospace-claim-window.sh reads this to pull the new window here.
          printf '%s' "$ws" >/tmp/aerospace-launch-ws
          (sleep 3; rm -f /tmp/aerospace-launch-ws) &

          # `open -n`, not the binary: the cask has no CLI on PATH, and -n is
          # what lets a second user-data-dir become a second instance.
          exec open -na "Brave Browser" --args \
            --user-data-dir="$data" \
            --profile-directory=Default \
            --new-window \
            --disable-breakpad \
            --no-pings \
            --disable-domain-reliability \
            --disable-background-networking \
            --no-default-browser-check \
            --no-first-run \
            "$@"
        '';
      };

      ghosttyDarwin = pkgs.writeShellApplication {
        name = "ghostty-activation";
        text = ''
          ${aeroPath}
          ws=$(aerospace list-workspaces --focused)

          id=$(aerospace list-windows --workspace "$ws" --format '%{window-id}|%{app-name}' 2>/dev/null |
            awk -F'|' '$2 ~ /Ghostty/ { print $1 }' | tail -1 || true)
          if [ -n "$id" ]; then
            exec aerospace focus --window-id "$id"
          fi

          # aerospace-claim-window.sh reads this to pull the new window here.
          printf '%s' "$ws" >/tmp/aerospace-launch-ws
          (sleep 3; rm -f /tmp/aerospace-launch-ws) &

          exec ghostty
        '';
      };
    in
    {
      home.packages = if isDarwin then [ braveDarwin ghosttyDarwin ] else [ braveLinux ];

      # Same filename shadows the packaged brave-origin.desktop, whose Exec has
      # no --user-data-dir and opens an empty third profile. home.file, not
      # xdg.desktopEntries: that is gated on xdg.enable, false here.
      home.file.".local/share/applications/brave-origin.desktop" = lib.mkIf (!isDarwin) {
        text = ''
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
    };
}
