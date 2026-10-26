#!/usr/bin/env dash
set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export calls="$work/calls"
mkdir "$work/bin"
cat > "$work/bin/nmcli" <<'EOF'
#!/usr/bin/env dash
printf '%s\n' "$*" >> "$calls"
case "$*" in
  '-g GENERAL.STATE device show wlan0') printf '%s\n' "${state:-100 (connected)}" ;;
  '-g GENERAL.AUTOCONNECT device show wlan0') printf '%s\n' "${autoconnect:-yes}" ;;
  '-g GENERAL.CONNECTION device show wlan0') printf '%s\n' "${connected:-eduroam}" ;;
  '--wait 15 -g SSID device wifi list ifname wlan0 --rescan yes')
    [ "${scan_fails:-no}" = no ] || exit 1
    printf '%s\n' "${visible:-eduroam}"
    ;;
  '--wait 20 connection up uuid 550e7a8e-c569-4b8f-a6f2-fee8c2a1cc1f ifname wlan0')
    [ "${connect_fails:-no}" = no ]
    ;;
  '--wait 20 connection up uuid d5dc12a7-ddc7-4911-9f19-64c7cfb208e1 ifname wlan0') ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$work/bin/nmcli"
export PATH="$work/bin:$PATH"

run() {
  : > "$calls"
  dash "$here/prefer-uynx.sh"
}

no_calls() {
  if grep -Eq "$1" "$calls"; then
    printf 'unexpected call matching %s\n' "$1" >&2
    exit 1
  fi
}

visible=uynx run
grep -q 'connection up uuid 550e7a8e' "$calls"
echo 'ok: switches to visible uynx'

visible=eduroam run
no_calls 'connection up'
echo 'ok: leaves the current connection alone when uynx is absent'

connected=uynx visible=uynx run
no_calls 'device wifi list|connection up'
echo 'ok: neither scans nor reconnects when already on uynx'

state='20 (unavailable)' visible=uynx run
no_calls 'device wifi list|connection up'
echo 'ok: respects Wi-Fi being turned off'

state='50 (connecting (configuring))' visible=uynx run
no_calls 'device wifi list|connection up'
echo 'ok: leaves an in-progress connection alone'

autoconnect=no visible=uynx run
no_calls 'device wifi list|connection up'
echo 'ok: respects a manual device disconnect'

scan_fails=yes visible=uynx run
no_calls 'connection up'
echo 'ok: a failed scan leaves the current connection alone'

connect_fails=yes visible=uynx run
grep -q 'connection up uuid d5dc12a7' "$calls"
echo 'ok: a failed uynx connection falls back to eduroam'
