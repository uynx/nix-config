{
  # Mod+N / Mod+M browser launchers for AeroSpace: focus a matching window in
  # the focused workspace before spawning. niri has no equivalent because it
  # spawns per output, hence a separate module rather than a branch in the
  # Linux one. Mod+P is bound straight to ghostty — it should always open a
  # new window, and aerospace-claim-window.sh already snaps it to the
  # focused workspace.
  flake.homeModules.launchersMacos =
    { pkgs, ... }:
    let
      # AeroSpace runs exec-and-forget under /bin/bash, whose PATH has neither
      # profile on it.
      aeroPath = ''
        me=$(id -un)
        export PATH="/etc/profiles/per-user/$me/bin:/run/current-system/sw/bin:$PATH"
      '';

      brave = pkgs.writeShellApplication {
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

    in
    {
      home.packages = [ brave ];
    };
}
