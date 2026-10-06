#!/usr/bin/env dash
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
fails=0

fake_sysfs() {
    ac=$1 e_cap=$2 p_cap=$3
    rm -rf "$work/sys"
    mkdir -p "$work/sys/class/power_supply/macsmc-ac"
    [ "$ac" = missing ] || echo "$ac" >"$work/sys/class/power_supply/macsmc-ac/online"
    for spec in "policy0 2064000 $e_cap" "policy2 3036000 $p_cap" "policy6 3036000 $p_cap"; do
        set -- $spec
        d="$work/sys/devices/system/cpu/cpufreq/$1"
        mkdir -p "$d"
        echo "$2" >"$d/cpuinfo_max_freq"
        echo "$3" >"$d/scaling_max_freq"
    done
}

caps() {
    for p in policy0 policy2 policy6; do
        cat "$work/sys/devices/system/cpu/cpufreq/$p/scaling_max_freq"
    done | tr '\n' ' '
}

check() {
    name=$1 want=$2
    SYSFS="$work/sys" bash -euo pipefail "$here/cpu-battery-cap.sh" >/dev/null 2>&1
    code=$?
    got=$(caps)
    if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then
        echo "ok   $name"
    else
        echo "FAIL $name (exit $code, caps '$got', wanted '$want')"
        fails=$((fails + 1))
    fi
}

fake_sysfs 0 2064000 3036000
check "on battery the performance clusters drop to 2.45 GHz and the efficiency cluster stays" "2064000 2448000 2448000 "

fake_sysfs 1 2064000 2448000
check "on AC every cluster returns to its own hardware maximum" "2064000 3036000 3036000 "

fake_sysfs missing 2064000 2448000
check "an unreadable AC state restores full speed and succeeds" "2064000 3036000 3036000 "

[ "$fails" -eq 0 ]
