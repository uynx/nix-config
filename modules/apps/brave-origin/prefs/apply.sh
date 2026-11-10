dir=$1
shift
lock=$(readlink "$dir/SingletonLock" 2>/dev/null || true)
# Brave rewrites its prefs on exit, so a merge under a running Brave is lost.
if [ -n "$lock" ] && kill -0 "${lock##*-}" 2>/dev/null; then
  echo "brave-prefs: Brave is running in $dir, settings apply at the next reb with it closed"
  exit 0
fi
for pair in "$@"; do
  snap=${pair%%:*}
  file=$dir/${pair#*:}
  mkdir -p "$(dirname "$file")"
  if [ -s "$file" ]; then
    jq -s '.[0] * .[1]' "$file" "$snap" >"$file.tmp"
  else
    cp "$snap" "$file.tmp"
  fi
  chmod 600 "$file.tmp"
  mv "$file.tmp" "$file"
done
