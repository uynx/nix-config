#!/usr/bin/env bash

VOL_INFO=$(osascript -e "get volume settings")
VOLUME=$(echo "$VOL_INFO" | awk -F', ' '{print $1}' | awk -F':' '{print $2}' | xargs)
MUTED=$(echo "$VOL_INFO" | awk -F', ' '{print $4}' | awk -F':' '{print $2}' | xargs)

if [ "$MUTED" = "true" ]; then
  sketchybar --set "$NAME" icon="󰝟" label="Muted"
else
  if [ "$VOLUME" -eq 0 ]; then
    ICON="󰝟"
  elif [ "$VOLUME" -lt 30 ]; then
    ICON="󰕿"
  elif [ "$VOLUME" -lt 70 ]; then
    ICON="󰖀"
  else
    ICON="󰕾"
  fi
  sketchybar --set "$NAME" icon="$ICON" label="${VOLUME}%"
fi
