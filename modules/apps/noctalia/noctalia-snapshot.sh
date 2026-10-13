file=${NOCTALIA_SNAPSHOT_FILE:-$HOME/nix-config/modules/apps/noctalia/settings.json}

live=$(noctalia-shell ipc call state all | jq -S .settings) || {
  echo "noctalia is not running, settings.json unchanged" >&2
  exit 0
}

# Keys default.nix overrides at build time; the live copy holds store paths for them.
echo "$live" | jq -S --slurpfile repo "$file" '
  $repo[0] as $r
  | .hooks.enabled = $r.hooks.enabled
  | .hooks.startup = $r.hooks.startup
  | .hooks.screenUnlock = $r.hooks.screenUnlock
  | .wallpaper.directory = $r.wallpaper.directory
  | del(.. | select(type == "object" and .defaultSettings == {}) | .defaultSettings)
' >"$file.tmp"
mv "$file.tmp" "$file"
