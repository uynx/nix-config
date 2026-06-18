#!/usr/bin/env bash

# Get CPU usage
NUM_CORES=$(sysctl -n hw.logicalcpu)
CPU_USAGE=$(ps -A -o %cpu | awk -v cores="$NUM_CORES" '{s+=$1} END {printf "%.0f", s/cores}')

# Get Memory usage
PAGESIZE=$(pagesize)
VM_STATS=$(vm_stat)
ACTIVE=$(echo "$VM_STATS" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
WIRED=$(echo "$VM_STATS" | grep "Pages wired" | awk '{print $4}' | sed 's/\.//')
COMPRESSED=$(echo "$VM_STATS" | grep "Pages occupied by compressor" | awk '{print $5}' | sed 's/\.//')

USED_PAGES=$((ACTIVE + WIRED + COMPRESSED))
USED_BYTES=$((USED_PAGES * PAGESIZE))
TOTAL_BYTES=$(sysctl -n hw.memsize)
MEM_USAGE=$((USED_BYTES * 100 / TOTAL_BYTES))

# Set colors based on load
if [ "$CPU_USAGE" -gt 80 ] || [ "$MEM_USAGE" -gt 80 ]; then
  COLOR="0xffbc5215" # Flexoki Orange / Warn
else
  COLOR="0xffcecdc3" # Flexoki Light Grey / Normal
fi

sketchybar --set "$NAME" label=" ${CPU_USAGE}%   ${MEM_USAGE}%" label.color="$COLOR"
