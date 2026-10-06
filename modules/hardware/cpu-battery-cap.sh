sys=${SYSFS:-/sys}
cap=2448000
online=$(cat "$sys/class/power_supply/macsmc-ac/online" 2>/dev/null || echo 1)

for p in "$sys"/devices/system/cpu/cpufreq/policy*; do
  hw=$(cat "$p/cpuinfo_max_freq")
  want=$hw
  if [ "$online" = 0 ] && [ "$hw" -gt "$cap" ]; then
    want=$cap
  fi
  echo "$want" >"$p/scaling_max_freq"
done
