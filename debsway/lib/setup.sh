#!/usr/bin/env bash
# =======================================================
# debsway/lib/setup.sh — `debsway setup` first-run wizard
# =======================================================
[ -n "${_DEBSWAY_LIB_SETUP_LOADED:-}" ] && return 0
_DEBSWAY_LIB_SETUP_LOADED=1

cmd_setup() {
    # Unattended mode (install.sh / run.sh --yes): the wizard is inherently
    # interactive, so keep every current setting instead of half-prompting.
    if [ -n "${DEBSWAY_ASSUME_YES:-}" ]; then
        d_ok "Setup skipped (DEBSWAY_ASSUME_YES=1) — theme, background, touchpad and night-light kept as-is."
        return 0
    fi
    echo
    echo "──────────────────────────────────────────────"
    echo "  DebSway first-run setup"
    echo "──────────────────────────────────────────────"

    # 1. theme
    local themes=() name reply="" n i=1 cur
    cur="$(current_theme)"
    while IFS= read -r name; do themes+=("$name"); done < <(theme_list)
    echo
    echo "Current theme: $cur"
    for name in "${themes[@]}"; do
        printf '  %2d. %s\n' "$i" "$name"
        i=$((i + 1))
    done
    read -rp "Pick a theme number (default: keep current): " reply || true
    case "$reply" in
        ''|*[!0-9]*) ;; # empty or non-numeric: keep current
        *)
            if [ "$reply" -ge 1 ] && [ "$reply" -le "${#themes[@]}" ]; then
                theme_set "${themes[$((reply - 1))]}"
            else
                d_warn "Theme $reply out of range — keeping $cur."
            fi
            ;;
    esac

    # 2. background
    read -rp "Browse/set background now? (y/N): " reply || true
    case "$reply" in y|Y) cmd_bg panel ;; esac

    # 3. touchpad tap-to-click
    local tap="unknown"
    if is_under_sway && command -v jq >/dev/null 2>&1; then
        tap="$(swaymsg -t get_inputs 2>/dev/null | jq -r '[.[]|select(.type=="touchpad")|.libinput.tap_enabled][0] // "unknown"' 2>/dev/null)"
        [ "$tap" = "null" ] && tap="unknown"
    fi
    read -rp "Tap-to-click on touchpad? [currently ${tap}] (Y/n): " reply || true
    case "${reply:-Y}" in
        n|N)
            if is_under_sway; then
                swaymsg "input type:touchpad tap disabled" >/dev/null 2>&1 || d_warn "No touchpad found."
            else
                d_warn "Not under sway — tap setting applies at next login (baked into sway/config)."
            fi
            ;;
        *)
            if is_under_sway; then
                swaymsg "input type:touchpad tap enabled" >/dev/null 2>&1 || d_warn "No touchpad found."
            fi
            ;;
    esac

    # 4. night-light coordinates (gammastep ships Bangkok defaults; adjust here)
    local gc="$DS_CONFIG/gammastep/config.ini"
    if [ -f "$gc" ]; then
        read -rp "Edit night-light lat/lon now (gammastep ships Bangkok defaults)? (y/N): " reply || true
        # shellcheck disable=SC2086: $EDITOR may carry flags (e.g. `code --wait`).
        case "$reply" in y|Y) ${EDITOR:-nano} "$gc" ;; esac
    fi

    echo
    d_ok "Setup complete. Reload sway (\$mod+Shift+C) if needed."
}