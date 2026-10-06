sock=${LID_SAVER_SOCK:-/tmp/waydroid-qmp.sock}
[ -S "$sock" ] || exit 0

qmp() {
  printf '{"execute":"qmp_capabilities"}\n{"execute":"%s"}\n' "$1" | socat -t1 - "UNIX-CONNECT:$sock" >/dev/null
}

external=$(niri msg -j outputs | jq '[keys[] | select(startswith("eDP") | not)] | length')

if [ "${1:-}" = close ] && [ "$external" -eq 0 ]; then
  qmp stop
elif [ "${1:-}" = open ]; then
  qmp cont
fi
