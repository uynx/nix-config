#!/usr/bin/env dash
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

run() {
    name=$1 appid=$2 want=$3
    got=$(bash -euo pipefail "$here/game-icon.sh" "$work/Steam" "$appid" 2>&1)
    code=$?
    if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then
        echo "ok   $name"
    else
        echo "FAIL $name (exit $code, got '$got' wanted '$want')"
        fails=$((fails + 1))
    fi
}

cache="$work/Steam/appcache/librarycache"
mkdir -p "$cache/3540"
touch "$cache/3540/41ec4d1b164eaea5a2520e6aef6dada128d32acc.jpg" "$cache/3540/header.jpg" "$cache/3540/library_600x900.jpg"
run "a game with a cached client icon uses it" \
    3540 "$cache/3540/41ec4d1b164eaea5a2520e6aef6dada128d32acc.jpg"

mkdir -p "$cache/32440"
touch "$cache/32440/header.jpg" "$cache/32440/library_600x900.jpg"
run "a game with only cover art falls back to the Steam icon" 32440 steam

run "a game Steam never cached falls back to the Steam icon" 674940 steam

exit "$fails"
