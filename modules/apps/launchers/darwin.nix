{
  flake.homeModules.launchersMacos =
    { pkgs, ... }:
    let
      common = import ./_common.nix;

      aeroPath = ''
        me=$(id -un)
        export PATH="/etc/profiles/per-user/$me/bin:/run/current-system/sw/bin:$PATH"
      '';

      brave = pkgs.writeShellApplication {
        name = "brave-activation";
        text = ''
          ${aeroPath}
          braveHome="$HOME/Library/Application Support/BraveSoftware"
          ${common.pickProfile}

          ws=$(aerospace list-workspaces --focused)
          id=$(aerospace list-windows --workspace "$ws" --format '%{window-id}|%{window-title}' 2>/dev/null |
            awk -F'|' -v s="Brave - $name" '$2 ~ s"$" { print $1; exit }' || true)
          if [ -n "$id" ]; then
            exec aerospace focus --window-id "$id"
          fi

          printf '%s' "$ws" >/tmp/aerospace-launch-ws
          (sleep 3; rm -f /tmp/aerospace-launch-ws) &

          exec open -na "Brave Browser" --args \
            --user-data-dir="$data" \
            --profile-directory=Default \
            --new-window \
            ${common.hardening} \
            "$@"
        '';
      };

    in
    {
      home.packages = [ brave ];
    };
}
