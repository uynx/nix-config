#!/usr/bin/env bash

PERCENTAGE=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(pmset -g batt | grep 'AC Power')

if [ -z "$PERCENTAGE" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  9[0-9]|100) ICON="󰁹" COLOR="0xff66800d" ;; # Green
  [6-8][0-9]) ICON="󰂀" COLOR="0xffcecdc3" ;;
  [3-5][0-9]) ICON="󰁾" COLOR="0xffcecdc3" ;;
  [1-2][0-9]) ICON="󰁻" COLOR="0xffbc5215" ;; # Orange
  *) ICON="󰂎" COLOR="0xffbc5215" ;;
esac

if [ -n "$CHARGING" ]; then
  ICON="󱐥"
fi

sketchybar --set "$NAME" icon="$ICON" label="${PERCENTAGE}%" icon.color="$COLOR"
