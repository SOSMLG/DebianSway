#!/usr/bin/env bash
# tempWarning.sh — CPU temperature monitor
# Polls sensors every 40 seconds, sends critical notification at 80°C+.

THRESHOLD=80

check_temp() {
    local temp
    temp=$(sensors 2>/dev/null | grep -m 1 'Package id 0' | awk '{print $4}' | tr -d '+°C')

    if [[ -n "$temp" && "${temp%.*}" -ge "$THRESHOLD" ]]; then
        notify-send -u critical "High Temperature" "CPU Temp is ${temp}°C"
    fi
}

while true; do
    check_temp
    sleep 40
done
