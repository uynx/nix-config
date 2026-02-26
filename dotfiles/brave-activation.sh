#!/bin/bash

if [[ -z "$1" || -z "$2" ]]; then
  exit 1
fi

export PATH="/Users/uynx/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

TARGET_PROFILE_DIR=$1
PROFILE_NAME=$2

WINDOW_ID=$(aerospace list-windows --all | tac | awk -v suffix="Brave - $PROFILE_NAME" '$0 ~ suffix"$" {print $1; exit}')

if [ -n "$WINDOW_ID" ]; then
  aerospace focus --window-id "$WINDOW_ID"
  osascript -e 'tell application "Brave Browser" to make new window'
else
  open -na "Brave Browser" --args \
    --no-first-run \
    --no-default-browser-check \
    --disable-prompt-on-repost \
    --disable-default-apps \
    --no-pings \
    --reduce-accept-language \
    --disable-domain-reliability \
    --disable-logging \
    --disable-crash-reporter \
    --disable-sync \
    --site-per-process \
    --disable-dev-shm-usage \
    --enable-dom-distiller \
    --enable-distillability-service \
    --disable-renderer-backgrounding \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    --num-raster-threads=4 \
    --enable-quic \
    --enable-features=EncryptedClientHello,StrictOriginIsolation,BlockInsecurePrivateNetworkRequests,BackForwardCache,BraveBlockScreenFingerprinting,BraveShowStrictFingerprintingMode,EnableFingerprintingProtectionFilter,EnableFingerprintingProtectionFilterInIncognito,ParallelDownloading,brave-copy-clean-link-by-default,HttpsByDefault,BraveAdblockDefault1pBlocking \
    --disable-features=PrivacySandboxAdsAPIs,Translate,IdleDetection,FedCm,WebBluetooth,WebUSB,WebOTP,GenericSensorExtraClasses,DataSharing,InProcessBraveAdsService,JourneysOmniboxAction,FedCmIdPregistration,OptimizationHintsFetchingSRP,BraveNewsCardPeek,BraveNewsFeedUpdate,BraveRewardsAllowSelfCustodyProviders,BraveRewardsPlatformCreatorDetection \
    --profile-directory="$TARGET_PROFILE_DIR"
fi
