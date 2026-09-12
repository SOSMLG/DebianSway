#!/usr/bin/env bash
# memoryUsage.sh — Memory usage module for Waybar (always prints one JSON line).
# Uses MemAvailable (the same honest figure `free` reports) instead of
# hand-rolling Total-Free-Buffers-Cached, which double-counts reclaimable
# slab. Never fails the bar: unreadable input prints a placeholder.

mem_kb() {
    awk -v k="$1" '$1 == k":" {print $2; exit}' /proc/meminfo 2>/dev/null
}

total="$(mem_kb MemTotal)"
avail="$(mem_kb MemAvailable)"

if [[ ! "$total" =~ ^[0-9]+$ ]] || [[ ! "$avail" =~ ^[0-9]+$ ]] || [ "$total" -eq 0 ]; then
    printf '{"text":" \uf1c0 ?","tooltip":"Memory: unreadable"}'
    exit 0
fi

used_gb="$(awk -v u="$((total - avail))" 'BEGIN {printf "%.1f", u/1048576}')"
total_gb="$(awk -v t="$total" 'BEGIN {printf "%.1f", t/1048576}')"

printf '{"text":" \uf1c0 %s/%sG","tooltip":"Memory: %sG / %sG used"}' \
    "$used_gb" "$total_gb" "$used_gb" "$total_gb"
