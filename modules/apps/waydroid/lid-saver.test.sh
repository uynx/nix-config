#!/usr/bin/env dash
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
fails=0

mkdir "$work/bin"
cat >"$work/bin/niri" <<'EOF'
#!/usr/bin/env dash
if [ "$*" = "msg -j outputs" ]; then
    printf '%s\n' "$FAKE_OUTPUTS"
else
    echo "$*" >>"$NIRI_LOG"
fi
EOF
chmod +x "$work/bin/niri"

run() {
    name=$1 outputs=$2 vm=$3 action=$4 want=$5 want_niri=$6
    sock="$work/qmp.sock" log="$work/qmp.log" niri_log="$work/niri.log"
    : >"$log"
    : >"$niri_log"
    rm -f "$sock"
    if [ "$vm" = up ]; then
        socat UNIX-LISTEN:"$sock" OPEN:"$log",creat,append >/dev/null 2>&1 &
        listener=$!
        while [ ! -S "$sock" ]; do sleep 0.05; done
    fi
    PATH="$work/bin:$PATH" FAKE_OUTPUTS="$outputs" LID_SAVER_SOCK="$sock" NIRI_LOG="$niri_log" \
        dash "$here/lid-saver.sh" "$action" >/dev/null 2>&1
    code=$?
    [ -n "${listener:-}" ] && kill "$listener" 2>/dev/null
    listener=
    got=$(rg -o '"execute": ?"(stop|cont)"' "$log" | rg -o 'stop|cont' | tr '\n' ' ')
    got_niri=$(sort "$niri_log" | tr '\n' '|' | sd '\|$' '')
    if [ "$code" -eq 0 ] && [ "$got" = "$want" ] && [ "$got_niri" = "$want_niri" ]; then
        echo "ok   $name"
    else
        echo "FAIL $name (exit $code, sent '${got}' wanted '${want}', niri '${got_niri}' wanted '${want_niri}')"
        fails=$((fails + 1))
    fi
}

builtin_only='{"eDP-1":{"name":"eDP-1"}}'
with_hdmi='{"eDP-1":{"name":"eDP-1"},"HDMI-A-1":{"name":"HDMI-A-1"}}'

run "close with only the built-in screen pauses the VM and blanks the screen" \
    "$builtin_only" up close "stop " "msg action power-off-monitors"
run "close with an external monitor leaves the VM running and switches off the built-in panel" \
    "$with_hdmi" up close "" "msg output eDP-1 off"
run "open with an external monitor resumes the VM and switches the built-in panel on" \
    "$with_hdmi" up open "cont " "msg action power-on-monitors|msg output eDP-1 on"
run "open resumes the VM and wakes the screen" \
    "$builtin_only" up open "cont " "msg action power-on-monitors"
run "close with no VM running still blanks the screen and succeeds" \
    "$builtin_only" down close "" "msg action power-off-monitors"

[ "$fails" -eq 0 ]
