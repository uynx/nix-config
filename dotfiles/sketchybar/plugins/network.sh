#!/usr/bin/env bash

STATE_FILE="/tmp/sketchybar_net_stats"

# Get current stats
STATS=$(netstat -ib -I en0 | grep -E "<Link#" | head -n 1)
CUR_RX=$(echo "$STATS" | awk '{print $7}')
CUR_TX=$(echo "$STATS" | awk '{print $10}')
CUR_TIME=$(date +%s)

# Read previous stats
if [ -f "$STATE_FILE" ]; then
  read -r PREV_RX PREV_TX PREV_TIME < "$STATE_FILE"
  INTERVAL=$((CUR_TIME - PREV_TIME))
  
  if [ "$INTERVAL" -gt 0 ]; then
    RX_SPEED=$(((CUR_RX - PREV_RX) / INTERVAL))
    TX_SPEED=$(((CUR_TX - PREV_TX) / INTERVAL))
  else
    RX_SPEED=0
    TX_SPEED=0
  fi
else
  RX_SPEED=0
  TX_SPEED=0
fi

# Write current stats to file
echo "$CUR_RX $CUR_TX $CUR_TIME" > "$STATE_FILE"

# Format speeds nicely (B/s, KB/s, MB/s)
format_speed() {
  local speed=$1
  if [ "$speed" -ge 1048576 ]; then
    printf "%.1f MB/s" "$(echo "$speed / 1048576" | bc -l)"
  elif [ "$speed" -ge 1024 ]; then
    printf "%.1f KB/s" "$(echo "$speed / 1024" | bc -l)"
  else
    printf "%d B/s" "$speed"
  fi
}

RX_FORMATTED=$(format_speed "$RX_SPEED")
TX_FORMATTED=$(format_speed "$TX_SPEED")

sketchybar --set "$NAME" label="󰕒 ${TX_FORMATTED}  󰇚 ${RX_FORMATTED}"
