#!/usr/bin/env dash
# Created for project [[agent_pc]]
set -eu
root=${RECOVERY_ROOT:?}
rules=$root/etc/udev/rules.d/99-local.rules
replacement=$(mktemp "$rules.XXXXXX")
trap 'rm -f "$replacement"' EXIT
awk '!(/0x1969/ && /0xe0b1/ && /ATTR\{remove\}="1"/)' "$rules" > "$replacement"
chmod 644 "$replacement"
mv -fT "$replacement" "$rules"
udevadm control --reload-rules
printf '1\n' > "$root/sys/bus/pci/rescan"
modprobe alx
udevadm settle --timeout=15
nmcli networking on
nmcli -t -f DEVICE,TYPE device | while IFS=: read -r device type; do
  if [ "$type" = ethernet ]; then
    printf 'Connecting %s to the router...\n' "$device"
    nmcli --wait 30 device connect "$device"
  fi
done
nmcli -f DEVICE,STATE,CONNECTION device
printf '\nEthernet restored. Leave the cable connected for the permanent fix.\n'
