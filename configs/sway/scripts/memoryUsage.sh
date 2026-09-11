#!/usr/bin/env bash
# memoryUsage.sh — Memory usage module for Waybar (returns JSON)
# Reads /proc/meminfo directly (htop-style calculation).

read -r total _ < <(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
read -r free _ < <(awk '/^MemFree:/ {print $2}' /proc/meminfo)
read -r buffers _ < <(awk '/^Buffers:/ {print $2}' /proc/meminfo)
read -r cached _ < <(awk '/^Cached:/ {print $2}' /proc/meminfo)
read -r sreclaimable _ < <(awk '/^SReclaimable:/ {print $2}' /proc/meminfo)

used_kb=$((total - free - buffers - cached - sreclaimable))
used_gb=$(awk "BEGIN {printf \"%.1f\", ${used_kb}/1048576}")
total_gb=$(awk "BEGIN {printf \"%.1f\", ${total}/1048576}")

echo "{\"text\":\" \uf1c0 ${used_gb}/${total_gb}G\",\"tooltip\":\"Memory: ${used_gb}G / ${total_gb}G used\"}"
