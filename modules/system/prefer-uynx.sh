#!/usr/bin/env dash
set -eu
export LC_ALL=C

case "$(nmcli -g GENERAL.STATE device show wlan0)" in
  '30 (disconnected)'|'100 (connected)') ;;
  *) exit 0 ;;
esac
[ "$(nmcli -g GENERAL.AUTOCONNECT device show wlan0)" = yes ] || exit 0
[ "$(nmcli -g GENERAL.CONNECTION device show wlan0)" != uynx ] || exit 0
visible=$(nmcli --wait 15 -g SSID device wifi list ifname wlan0 --rescan yes) || exit 0
printf '%s\n' "$visible" | grep -Fxq uynx || exit 0
if ! nmcli --wait 20 connection up uuid 550e7a8e-c569-4b8f-a6f2-fee8c2a1cc1f ifname wlan0; then
  nmcli --wait 20 connection up uuid d5dc12a7-ddc7-4911-9f19-64c7cfb208e1 ifname wlan0
fi
