#!/usr/bin/env bash

# Extract monitor ID (last field) and space number (middle field) from space.i.m
MONITOR_ID="${NAME##*.}"
SPACE_NUM=$(echo "$NAME" | cut -d'.' -f2)

# Fast path: check trigger variables first to avoid slow command spawns
if [ -z "$FOCUSED_WORKSPACE" ]; then
  FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused)
fi
if [ -z "$FOCUSED_MONITOR" ]; then
  FOCUSED_MONITOR=$(aerospace list-monitors --focused | cut -d'|' -f1 | xargs)
fi

# Highlight active workspace
if [ "$SPACE_NUM" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" \
             background.drawing=on \
             background.color=0xff3aa99f \
             label.color=0xff100f0f \
             icon.color=0xff100f0f
else
  sketchybar --set "$NAME" \
             background.drawing=off \
             label.color=0xffcecdc3 \
             icon.color=0xffcecdc3
fi

# Highlight active monitor borders
if [ "$MONITOR_ID" = "$FOCUSED_MONITOR" ]; then
  sketchybar --set "spaces.$MONITOR_ID" background.border_color=0xff205ea6 \
             --set "front_app_bracket.$MONITOR_ID" background.border_color=0xff205ea6 \
             --set "volume_bracket.$MONITOR_ID" background.border_color=0xff205ea6 \
             --set "brightness_bracket.$MONITOR_ID" background.border_color=0xff205ea6 \
             --set "weather_bracket.$MONITOR_ID" background.border_color=0xff205ea6 \
             --set "sys_bracket.$MONITOR_ID" background.border_color=0xff205ea6 \
             --set "clock_bracket.$MONITOR_ID" background.border_color=0xff205ea6 \
             --set "battery_bracket.$MONITOR_ID" background.border_color=0xff205ea6
else
  sketchybar --set "spaces.$MONITOR_ID" background.border_color=0x40cecdc3 \
             --set "front_app_bracket.$MONITOR_ID" background.border_color=0x40cecdc3 \
             --set "volume_bracket.$MONITOR_ID" background.border_color=0x40cecdc3 \
             --set "brightness_bracket.$MONITOR_ID" background.border_color=0x40cecdc3 \
             --set "weather_bracket.$MONITOR_ID" background.border_color=0x40cecdc3 \
             --set "sys_bracket.$MONITOR_ID" background.border_color=0x40cecdc3 \
             --set "clock_bracket.$MONITOR_ID" background.border_color=0x40cecdc3 \
             --set "battery_bracket.$MONITOR_ID" background.border_color=0x40cecdc3
fi
