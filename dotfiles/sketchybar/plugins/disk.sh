#!/usr/bin/env bash

DISK_INFO=$(df -h / | tail -n 1)
AVAIL=$(echo "$DISK_INFO" | awk '{print $4}')

sketchybar --set "$NAME" label="󰋊 ${AVAIL}"
