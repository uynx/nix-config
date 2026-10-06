sock=${LID_SAVER_SOCK:-/tmp/waydroid-qmp.sock}

qmp() {
  [ -S "$sock" ] || return 0
  printf '{"execute":"qmp_capabilities"}\n{"execute":"%s"}\n' "$1" | socat -t1 - "UNIX-CONNECT:$sock" >/dev/null || true
}

external=$(niri msg -j outputs | jq '[keys[] | select(startswith("eDP") | not)] | length')

if [ "${1:-}" = close ]; then
  if [ "$external" -eq 0 ]; then
    niri msg action power-off-monitors
    qmp stop
  else
    niri msg output eDP-1 off
  fi
elif [ "${1:-}" = open ]; then
  niri msg action power-on-monitors
  if [ "$external" -gt 0 ]; then
    niri msg output eDP-1 on
  fi
  qmp cont
fi
