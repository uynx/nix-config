#!/usr/bin/env sh

if [ -z "$1" ] || [ -z "$2" ]; then
  exit 1
fi

export PATH="/Users/uynx/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

TARGET_PROFILE_DIR=$1
PROFILE_NAME=$2

WINDOW_ID=$(aerospace list-windows --all | tac | awk -v suffix="Brave - $PROFILE_NAME" '$0 ~ suffix"$" {print $1; exit}')

if [ -n "$WINDOW_ID" ]; then
  aerospace focus --window-id "$WINDOW_ID"
  brave --new-window --profile-directory="$TARGET_PROFILE_DIR"
else
  brave --profile-directory="$TARGET_PROFILE_DIR" \
    --disable-3d-apis \
    --disable-background-networking \
    --disable-breakpad \
    --disable-device-discovery-notifications \
    --disable-domain-reliability \
    --disable-notifications \
    --disable-offer-store-unmasked-wallet-cards \
    --disable-reading-from-canvas \
    --disable-remote-fonts \
    --disable-shared-workers \
    --disable-signin-scoped-device-id \
    --disable-speech-api \
    --disable-sync \
    --disable-webrtc-hw-decoding \
    --disable-webrtc-hw-encoding \
    --disk-cache-size=1 \
    --document-user-activation-required \
    --enable-aggressive-domstorage-flushing \
    --enable-features=WebContentsForceDark,BraveShowStrictFingerprintingMode \
    --enable-strict-mixed-content-checking \
    --enable-strict-powerful-feature-restrictions \
    --enable-webrtc-srtp-aes-gcm \
    --enable-webrtc-srtp-encrypted-headers \
    --enable-webrtc-stun-origin \
    --enforce-webrtc-ip-permission-check \
    --extension-content-verification=enforce \
    --extensions-install-verification=enforce \
    --force-cert-verifier-builtin \
    --force-empty-corb-allowlist \
    --gpu-no-context-lost \
    --gpu-sandbox-failures-fatal \
    --gpu-sandbox-start-early \
    --js-flags="--no-expose-wasm" \
    --log-level=3 \
    --no-default-browser-check \
    --no-first-run \
    --no-pings \
    --no-referrers \
    --password-store=basic \
    --ssl-version-min=tls1.2 \
    --webgl-antialiasing-mode=none \
    --window-size=1280,720
fi
