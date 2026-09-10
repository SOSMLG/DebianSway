#!/usr/bin/env bash
# batteryWarning.sh — Battery monitor for ThinkPad L14 G2
# Polls upower every 5 minutes, sends notifications when low.

BATTERY="/org/freedesktop/UPower/devices/battery_BAT0"

check_battery() {
    local batt
    batt=$(upower -i "$BATTERY" 2>/dev/null | awk '/percentage/ {print $2}' | tr -d '%')
    [ -z "$batt" ] && return 1

    if [[ "$batt" -le 20 ]]; then
        notify-send -u critical "Need Juice" "Battery is at ${batt}%"
    elif [[ "$batt" -le 30 ]]; then
        notify-send -u low "Low Battery" "Battery is at ${batt}%"
    fi
}

while true; do
    state=$(upower -i "$BATTERY" 2>/dev/null | awk '/state/ {print $2}')
    if [[ "$state" == "discharging" ]]; then
        check_battery
    fi
    sleep 300
done
