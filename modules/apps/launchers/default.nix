{
  # App-launch shortcuts for Mod+P / Mod+N / Mod+M, previously loose shell
  # scripts in ~/dotfiles. Both were still querying `hyprctl`, which has not
  # existed since the move to niri, so neither had worked since the switch.
  #
  # These are niri-only. The old scripts also carried an aerospace branch for
  # macOS; that half is in the dotfiles repo's git history and should come back
  # as a darwin variant of this module when that host actually exists, rather
  # than sitting here untested.
  flake.homeModules.launchers =
    { pkgs, lib, ... }:
    let
      niri = lib.getExe pkgs.niri;
      jq = lib.getExe pkgs.jq;
    in
    {
      home.packages = [
        # Focus the ghostty on this workspace, or open one attached to that
        # workspace's own tmux session. `new-session -A` is attach-or-create, so
        # the whole thing is idempotent and there is no state to keep in sync.
        #
        # Keyed on the niri workspace id, which is stable for as long as the
        # workspace exists but is not reused across reboots — a deliberate
        # trade for keeping niri's dynamic workspaces rather than pinning six
        # named ones to outputs.
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

        # Launch a Brave profile. Separate --user-data-dir per profile is what
        # keeps the two genuinely independent; --profile-directory alone shares
        # one browser process between them.
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

      # Anything that opens a link — xdg-open, a chat client, a mail app — runs
      # brave-origin.desktop, whose packaged Exec carries no --user-data-dir and
      # so lands in ~/.config/BraveSoftware/Brave-Origin: a third, empty profile
      # with none of the logins, and a separate singleton lock, which is why it
      # also spawns its own window instead of a tab in the running browser.
      #
      # Same entry name as the package's, so this copy in ~/.local/share
      # shadows it and every consumer is fixed without touching mimeapps.
      #
      # home.file rather than xdg.desktopEntries: the latter routes through
      # xdg.dataFile, which is gated on `xdg.enable`, and that is false here —
      # so it writes nothing at all. (The same silence applies to the existing
      # xdg.desktopEntries.steam, which the Steam module's generator covers.)
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
