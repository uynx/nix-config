apk=${PHONE_SYNC_APK:?}
policy=${PHONE_SYNC_POLICY:?}
pkg=dev.uynx.siteblock

has() { rg -qF -- "$2" <<<"$1"; }

check() {
  local bad=0 dp eff p
  t() {
    local n=$1
    shift
    if "$@"; then echo "ok    $n"; else
      echo "FAIL  $n"
      bad=1
    fi
  }
  dp=$(adb shell dumpsys device_policy)
  eff=$(adb shell dumpsys user | awk '/Effective restrictions:/ && !d { f = 1; next } f && /:$/ { f = 0; d = 1 } f { print $1 }')

  t "device owner is $pkg" has "$dp" "ComponentInfo{$pkg/"
  t "private DNS mode is hostname" [ "$(adb shell settings get global private_dns_mode)" = hostname ]
  t "private DNS host is $(jq -r .privateDns "$policy")" [ "$(adb shell settings get global private_dns_specifier)" = "$(jq -r .privateDns "$policy")" ]
  for p in $(jq -r '.userRestrictions[]' "$policy"); do
    t "restriction $p" has "$eff" "$p"
  done
  for p in $(jq -r '.hidden[]' "$policy"); do
    t "$p hidden" has "$(adb shell dumpsys package "$p" | rg -m1 'User 0:')" hidden=true
  done

  # Without the policy this would open a blocked site on the phone.
  [ $bad = 0 ] || return 1
  adb shell am start -W -a android.intent.action.VIEW -d https://9gag.com -p com.brave.browser >/dev/null
  sleep 4
  t "Brave refuses 9gag.com" has "$(adb shell 'uiautomator dump /sdcard/sb.xml >/dev/null && cat /sdcard/sb.xml; rm -f /sdcard/sb.xml')" "This page is blocked"
  adb shell input keyevent KEYCODE_HOME

  return $bad
}

if [ "${1:-}" != --check ]; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  base64 -d "${PHONE_SYNC_KEYSTORE:-$HOME/.config/site-block/keystore.p12.b64}" >"$tmp/ks.p12"
  apksigner sign --ks "$tmp/ks.p12" --ks-pass pass:siteblock --key-pass pass:siteblock --out "$tmp/a.apk" "$apk"
  adb install -r "$tmp/a.apk"
  # GrapheneOS can leave the Network permission off, and the Private DNS probe runs in this app.
  adb shell pm grant "$pkg" android.permission.INTERNET
  # Android refuses a device owner while any account exists on the phone.
  has "$(adb shell dumpsys device_policy)" "ComponentInfo{$pkg/" || adb shell dpm set-device-owner "$pkg/.Admin"
fi
check
