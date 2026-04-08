#!/usr/bin/env sh

if [ -z "$1" ]; then
  exit 1
fi

export PATH="/Users/uynx/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

PROFILE_NAME=$1

LIBREWOLF_BIN="/Users/uynx/.nix-profile/Applications/LibreWolf.app/Contents/MacOS/librewolf"

WINDOW_ID=$(aerospace list-windows --all --format "%{window-id}|%{app-bundle-id}|%{window-title}" |
  grep "org.nixos.librewolf" |
  grep "\[$PROFILE_NAME\]$" |
  tail -n 1 | cut -d'|' -f1)

if [ -n "$WINDOW_ID" ]; then
  aerospace focus --window-id "$WINDOW_ID"
  "$LIBREWOLF_BIN" -P "$PROFILE_NAME" --no-remote --new-window &
else
  "$LIBREWOLF_BIN" -P "$PROFILE_NAME" --no-remote &
fi
