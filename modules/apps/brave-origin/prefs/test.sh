#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
run() { bash -euo pipefail "$here/apply.sh" "$@"; }
fail() { echo "FAIL: $1" >&2; exit 1; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT

echo '{"brave":{"tabs":{"vertical_tabs_enabled":true}},"browser":{"theme":{"user_color2":5}}}' >"$t/snap.json"

d=$t/merge
mkdir -p "$d/Default"
echo '{"brave":{"tabs":{"vertical_tabs_enabled":false},"stats":7},"account":"kept"}' >"$d/Default/Preferences"
run "$d" "$t/snap.json:Default/Preferences"
[ "$(jq -c . "$d/Default/Preferences")" = '{"brave":{"tabs":{"vertical_tabs_enabled":true},"stats":7},"account":"kept","browser":{"theme":{"user_color2":5}}}' ] ||
  fail "merge: $(cat "$d/Default/Preferences")"

d=$t/new
run "$d" "$t/snap.json:Profile 1/Preferences"
[ "$(jq -c . "$d/Profile 1/Preferences")" = '{"brave":{"tabs":{"vertical_tabs_enabled":true}},"browser":{"theme":{"user_color2":5}}}' ] ||
  fail "create"

d=$t/running
mkdir -p "$d/Default"
echo '{"a":1}' >"$d/Default/Preferences"
ln -s "$(hostname)-$$" "$d/SingletonLock"
run "$d" "$t/snap.json:Default/Preferences" >/dev/null
[ "$(jq -c . "$d/Default/Preferences")" = '{"a":1}' ] || fail "touched a running profile"

d=$t/stale
mkdir -p "$d/Default"
echo '{"a":1}' >"$d/Default/Preferences"
ln -s "$(hostname)-999999999" "$d/SingletonLock"
run "$d" "$t/snap.json:Default/Preferences"
[ "$(jq -r .browser.theme.user_color2 "$d/Default/Preferences")" = 5 ] || fail "stale lock blocked apply"

echo ok
