#!/usr/bin/env dash
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

mkdir "$work/bin"
cat >"$work/bin/noctalia-shell" <<'EOF'
#!/usr/bin/env dash
[ -n "${FAKE_LIVE:-}" ] || exit 1
printf '%s\n' "$FAKE_LIVE"
EOF
chmod +x "$work/bin/noctalia-shell"

repo='{"appLauncher":{"position":"center"},"bar":{"position":"top","widgets":{"right":[{"id":"Clock"}]}},"hooks":{"enabled":false,"screenUnlock":"","startup":""},"wallpaper":{"directory":"/home/uynx/dotfiles"}}'

run() {
    name=$1 live=$2 want=$3
    file="$work/settings.json"
    printf '%s\n' "$repo" | jq -S . >"$file"
    PATH="$work/bin:$PATH" FAKE_LIVE="$live" NOCTALIA_SNAPSHOT_FILE="$file" \
        bash -euo pipefail "$here/noctalia-snapshot.sh" >/dev/null 2>&1
    code=$?
    got=$(jq -cS . "$file")
    want=$(printf '%s' "$want" | jq -cS .)
    if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then
        echo "ok   $name"
    else
        echo "FAIL $name (exit $code, got $got, wanted $want)"
        fails=$((fails + 1))
    fi
}

live_changed='{"settings":{"appLauncher":{"position":"top_center"},"bar":{"position":"top","widgets":{"right":[{"id":"Clock"}]}},"hooks":{"enabled":true,"screenUnlock":"/nix/store/x-systemd/bin/loginctl unlock-session","startup":"noctalia-shell ipc call wallpaper set /nix/store/x-wallpapers/wallpaper.png all"},"wallpaper":{"directory":"/nix/store/x-wallpapers"}},"state":{}}'
live_widget='{"settings":{"appLauncher":{"position":"center"},"bar":{"position":"top","widgets":{"right":[{"id":"Clock","defaultSettings":{}}]}},"hooks":{"enabled":true,"screenUnlock":"/nix/store/x","startup":"/nix/store/y"},"wallpaper":{"directory":"/nix/store/z"}},"state":{}}'

run "a panel change reaches the repo file and the store-path values stay as the repo has them" \
    "$live_changed" \
    '{"appLauncher":{"position":"top_center"},"bar":{"position":"top","widgets":{"right":[{"id":"Clock"}]}},"hooks":{"enabled":false,"screenUnlock":"","startup":""},"wallpaper":{"directory":"/home/uynx/dotfiles"}}'
run "an empty defaultSettings that noctalia adds to a widget is dropped" \
    "$live_widget" "$repo"
run "noctalia not running leaves the file untouched and succeeds" \
    "" "$repo"

[ "$fails" -eq 0 ]
