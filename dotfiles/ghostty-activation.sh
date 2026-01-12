#!/bin/bash
TAC_CMD="/run/current-system/sw/bin/tac"

CURRENT_WORKSPACE=$(aerospace list-workspaces --focused | awk '{print $1}')
WINDOW_ID=$(aerospace list-windows --workspace "$CURRENT_WORKSPACE" | $TAC_CMD | awk '$3 == "Ghostty" {print $1; exit}')

if [ -n "$WINDOW_ID" ]; then
    aerospace focus --window-id "$WINDOW_ID"
    osascript -e 'tell application "system events" to keystroke "n" using {command down}'
else
    open -na 'Ghostty'
fi
    
