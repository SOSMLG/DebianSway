#!/usr/bin/env bash
# =======================================================
# debsway/lib/setup.sh — `debsway setup` first-run wizard
# =======================================================
[ -n "${_DEBSWAY_LIB_SETUP_LOADED:-}" ] && return 0
_DEBSWAY_LIB_SETUP_LOADED=1

cmd_setup() {
    echo
    echo "──────────────────────────────────────────────"
    echo "  DebSway first-run setup"
    echo "──────────────────────────────────────────────"

    # 1. theme
    local themes=() name reply n i=1 cur
    cur="$(current_theme)"
    while IFS= read -r name; do themes+=("$name"); done < <(theme_list)
    echo
    echo "Current theme: $cur"
    for name in "${themes[@]}"; do
        printf '  %2d. %s\n' "$i" "$name"
        i=$((i + 1))
    done
    read -rp "Pick a theme number (default: keep current): " reply
    if [ -n "$reply" ] && [ "$reply" -ge 1 ] && [ "$reply" -le "${#themes[@]}" ]; then
        theme_set "${themes[$((reply - 1))]}"
    fi

    # 2. background
    read -rp "Browse/set background now? (y/N): " reply
    case "$reply" in y|Y) cmd_bg panel ;; esac

    # 3. touchpad tap-to-click
    local tap
    tap="$(is_under_sway && swaymsg -t get_inputs 2>/dev/null | jq -r '.[]|select(.type=="touchpad")|.libinput.tap_enabled' | head -1)"
    read -rp "Tap-to-click on touchpad? [currently ${tap:-unknown}] (Y/n): " reply
    case "${reply:-Y}" in
        n|N) swaymsg "input type:touchpad tap disabled" >/dev/null 2>&1 ;;
        *)   swaymsg "input type:touchpad tap enabled" >/dev/null 2>&1 ;;
    esac

    # 4. night-light coordinates (gammastep)
    local gc="$DS_CONFIG/gammastep/config.ini"
    if [ -f "$gc" ]; then
        read -rp "Edit night-light lat/lon now (gammastep requires coordinates)? (y/N): " reply
        case "$reply" in y|Y) ${EDITOR:-nano} "$gc" ;; esac
    fi

    echo
    d_ok "Setup complete. Reload sway (\$mod+Shift+C) if needed."
}