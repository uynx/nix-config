{
  # Mod+P / Mod+N / Mod+M launchers. niri-only; the old aerospace branch is in
  # dotfiles history if a darwin host ever needs it.
  flake.homeModules.launchers =
    { pkgs, lib, ... }:
    let
      niri = lib.getExe pkgs.niri;
      jq = lib.getExe pkgs.jq;
    in
    {
      home.packages = [
        # Focus this workspace's ghostty, or open one on its own tmux session.
        (pkgs.writeShellApplication {
          name = "ghostty-activation";
          runtimeInputs = [
            pkgs.ghostty
            pkgs.tmux
          ];
          text = ''
            ws=$(${niri} msg -j workspaces | ${jq} -r 'first(.[] | select(.is_focused) | .id)')

            existing=$(${niri} msg -j windows | ${jq} -r --argjson ws "$ws" \
              'first(.[] | select(.app_id == "com.mitchellh.ghostty" and .workspace_id == $ws) | .id) // empty')

            if [ -n "$existing" ]; then
              exec ${niri} msg action focus-window --id "$existing"
            fi

            exec ghostty -e tmux new-session -A -s "ws$ws"
          '';
        })

        # A separate --user-data-dir per profile is what keeps the two
        # independent; --profile-directory alone shares one browser process.
        (pkgs.writeShellApplication {
          name = "brave-activation";
          text = ''
            braveHome="''${XDG_CONFIG_HOME:-$HOME/.config}/BraveSoftware"

            case "''${1:-}" in
              Personal) data="$braveHome/Brave-Browser" ;;
              School)   data="$braveHome/Brave-Browser-School" ;;
              *) echo "usage: brave-activation Personal|School" >&2; exit 1 ;;
            esac
            shift

            exec brave-origin \
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
        })
      ];

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
