#!/usr/bin/env dash
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT
fails=0

mkdir "$work/bin"
cat >"$work/bin/niri" <<'EOF'
#!/usr/bin/env dash
printf '%s\n' "$FAKE_OUTPUTS"
EOF
chmod +x "$work/bin/niri"

run() {
    name=$1 outputs=$2 vm=$3 action=$4 want=$5
    sock="$work/qmp.sock" log="$work/qmp.log"
    : >"$log"
    rm -f "$sock"
    if [ "$vm" = up ]; then
        socat UNIX-LISTEN:"$sock" OPEN:"$log",creat,append >/dev/null 2>&1 &
        listener=$!
        while [ ! -S "$sock" ]; do sleep 0.05; done
    fi
    PATH="$work/bin:$PATH" FAKE_OUTPUTS="$outputs" LID_SAVER_SOCK="$sock" \
        dash "$here/lid-saver.sh" "$action" >/dev/null 2>&1
    code=$?
    [ -n "${listener:-}" ] && kill "$listener" 2>/dev/null
    listener=
    got=$(rg -o '"execute": ?"(stop|cont)"' "$log" | rg -o 'stop|cont' | tr '\n' ' ')
    if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then
        echo "ok   $name"
    else
        echo "FAIL $name (exit $code, sent '${got}', wanted '${want}')"
        fails=$((fails + 1))
    fi
}

builtin_only='{"eDP-1":{"name":"eDP-1"}}'
with_hdmi='{"eDP-1":{"name":"eDP-1"},"HDMI-A-1":{"name":"HDMI-A-1"}}'

run "close with only the built-in screen pauses the VM" "$builtin_only" up close "stop "
run "close with an external monitor leaves the VM running" "$with_hdmi" up close ""
run "open resumes the VM" "$builtin_only" up open "cont "
run "close with no VM running does nothing and succeeds" "$builtin_only" down close ""

[ "$fails" -eq 0 ]
