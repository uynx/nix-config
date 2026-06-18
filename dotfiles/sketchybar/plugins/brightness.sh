#!/usr/bin/env bash

if [ "$SENDER" = "brightness_change" ]; then
  BRIGHTNESS="$INFO"
else
  BRIGHTNESS=$("$CONFIG_DIR/plugins/brightness_helper")
fi

if [ -z "$BRIGHTNESS" ]; then
  BRIGHTNESS=0
fi

if [ "$BRIGHTNESS" -lt 30 ]; then
  ICON="󰃞"
elif [ "$BRIGHTNESS" -lt 70 ]; then
  ICON="󰃟"
else
  ICON="󰃠"
fi

sketchybar --set "$NAME" icon="$ICON" label="${BRIGHTNESS}%"
