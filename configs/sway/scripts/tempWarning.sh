#!/usr/bin/env bash
# tempWarning.sh — CPU temperature monitor
# Polls sensors every 40 seconds, sends critical notification at 80°C+.
# Matches Intel (`Package id 0`) and AMD (`Tctl`, k10temp on Ryzen) labels —
# this ThinkPad L14 Gen 2 is AMD, where the Intel-only match never fired.

THRESHOLD=80

check_temp() {
    local temp
    temp=$(sensors 2>/dev/null | grep -m 1 -E 'Package id 0|Tctl:' \
        | grep -oE '[+-]?[0-9]+(\.[0-9]+)?°C' | head -1 | tr -d '+°C')

    if [[ -n "$temp" && "${temp%.*}" -ge "$THRESHOLD" ]]; then
        notify-send -u critical "High Temperature" "CPU Temp is ${temp}°C"
    fi
}

while true; do
    check_temp
    sleep 40
done
