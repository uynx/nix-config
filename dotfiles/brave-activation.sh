#!/usr/bin/env sh

if [ -z "$1" ] || [ -z "$2" ]; then
  exit 1
fi

export PATH="/Users/uynx/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

TARGET_PROFILE_DIR=$1
PROFILE_NAME=$2

# Focus existing window if available (via aerospace)
WINDOW_ID=$(aerospace list-windows --all | tac | awk -v suffix="Brave - $PROFILE_NAME" '$0 ~ suffix"$" {print $1; exit}')

if [ -n "$WINDOW_ID" ]; then
  aerospace focus --window-id "$WINDOW_ID"
  brave --new-window --profile-directory="$TARGET_PROFILE_DIR"
else
  # Launch with lean, anonymity-focused flags (Persistence enabled: no --incognito)
  brave --profile-directory="$TARGET_PROFILE_DIR" \
    --disable-breakpad \
    --no-pings \
    --disable-domain-reliability \
    --disable-background-networking \
    --no-default-browser-check \
    --no-first-run
fi
