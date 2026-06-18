#!/usr/bin/env bash

MONITOR_ID="${NAME##*.}"

if [ -z "$FOCUSED_APP" ]; then
  APP_NAME=$(aerospace list-windows --focused --format '%{app-name}')
else
  APP_NAME="$FOCUSED_APP"
fi

if [ -z "$FOCUSED_MONITOR" ]; then
  FOCUSED_MONITOR=$(aerospace list-monitors --focused | cut -d'|' -f1 | xargs)
fi

if [ -z "$APP_NAME" ]; then
  APP_NAME="Finder"
fi

case "$APP_NAME" in
  "Brave Browser"|"Brave") ICON="󰖟" ;;
  "Ghostty") ICON="" ;;
  "Neovim"|"nvim") ICON="" ;;
  "VSCodium"|"VS Code"|"Code") ICON="󰨞" ;;
  "Slack") ICON="󰒱" ;;
  "Discord") ICON="󰙯" ;;
  "Spotify") ICON="󰓇" ;;
  "Finder") ICON="󰀶" ;;
  "LibreOffice"*) ICON="󰈙" ;;
  "Cake Wallet") ICON="🪙" ;;
  *) ICON="󰣆" ;;
esac

# Update label and icon
sketchybar --set "$NAME" label="$APP_NAME" icon="$ICON"

# Sync borders on monitor focus changes
if [ "$MONITOR_ID" = "$FOCUSED_MONITOR" ]; then
  sketchybar --set "spaces.$MONITOR_ID" background.border_color=0xff205ea6 \
             --set "front_app_bracket.$MONITOR_ID" background.border_color=0xff205ea6 \
             --set "status_bracket.$MONITOR_ID" background.border_color=0xff205ea6
else
  sketchybar --set "spaces.$MONITOR_ID" background.border_color=0x40cecdc3 \
             --set "front_app_bracket.$MONITOR_ID" background.border_color=0x40cecdc3 \
             --set "status_bracket.$MONITOR_ID" background.border_color=0x40cecdc3
fi
