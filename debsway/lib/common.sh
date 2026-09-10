#!/usr/bin/env bash
# =======================================================
# debsway/lib/common.sh — shared helpers for the DebSway CLI
# -------------------------------------------------------
# Sourced by bin/debsway and every lib/*.sh. Everything
# path-related resolves relative to the tool's install dir
# (~/.local/share/debsway by default), so moving the tree
# or invoking via /usr/local/bin symlink keeps working.
# =======================================================
[ -n "${_DEBSWAY_LIB_COMMON_LOADED:-}" ] && return 0
_DEBSWAY_LIB_COMMON_LOADED=1

# --- self-location ----------------------------------------------------------
DS_SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DS_LIB_DIR="$(cd "$(dirname "$DS_SELF")" && pwd)"
DS_INSTALL="${DEBSWAY_HOME:-$HOME/.local/share/debsway}"
DS_BIN_DIR="$DS_INSTALL/bin"
DS_LIB="${DS_INSTALL}/lib"
DS_THEMES="$DS_INSTALL/themes"
DS_TPL="$DS_THEMES/_base/tpl"
DS_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/debsway"
DS_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$DS_STATE"

# --- CLI colors ---------------------------------------------------------------
D_RED="\033[0;31m"; D_GREEN="\033[0;32m"; D_YELLOW="\033[1;33m"; D_CYAN="\033[0;36m"; D_RESET="\033[0m"
d_log()  { echo -e "${D_CYAN}[*]${D_RESET} $*"; }
d_ok()   { echo -e "${D_GREEN}[OK]${D_RESET} $*"; }
d_warn() { echo -e "${D_YELLOW}[!]${D_RESET} $*"; }
d_err()  { echo -e "${D_RED}[ERROR]${D_RESET} $*" >&2; }

# --- palette / theme plumbing ------------------------------------------------
current_theme() {
    if [ -n "${DEBSWAY_THEME:-}" ]; then
        printf '%s\n' "$DEBSWAY_THEME"
    elif [ -f "$DS_STATE/theme" ]; then
        cat "$DS_STATE/theme"
    else
        printf '%s\n' "catppuccin-mocha-red"
    fi
}

theme_dir() { printf '%s\n' "$DS_THEMES/$1"; }

# load_palette <dir> — sources a theme's palette.sh which sets C_* variables.
# Validates afterwards that the CNT was fully populated.
load_palette() {
    local dir="$1" f="${1%/}/palette.sh"
    if [ ! -f "$f" ]; then
        d_err "No palette.sh in $dir"
        return 1
    fi
    unset _PALETTE_OK
    . "$f"
    local missing=0 var
    for var in C_BG C_MANTLE C_CRUST C_SURFACE0 C_SURFACE1 C_SURFACE2 C_OVERLAY \
               C_TEXT C_SUBTEXT0 C_SUBTEXT1 C_ACCENT \
               C_RED C_GREEN C_YELLOW C_BLUE C_PURPLE C_PINK C_TEAL C_ORANGE \
               C_T0 C_T1 C_T2 C_T3 C_T4 C_T5 C_T6 C_T7 \
               C_TB0 C_TB1 C_TB2 C_TB3 C_TB4 C_TB5 C_TB6 C_TB7; do
        if [ -z "${!var:-}" ]; then
            d_err "palette $dir is missing '$var'"
            missing=1
        fi
    done
    [ "$missing" -eq 0 ]
}

# notify <summary> <body?>
notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a debsway "$1" "${2:-}" >/dev/null 2>&1 || true
}

# is_under_sway — true if swaymsg reaches a running sway
is_under_sway() {
    command -v swaymsg >/dev/null 2>&1 && [ -n "${SWAYSOCK:-}" ] \
        && swaymsg -t get_version >/dev/null 2>&1
}

# wofi_pick <prompt> — reads stdin lines, prints the selected one (or empty)
wofi_pick() {
    if ! command -v wofi >/dev/null 2>&1; then
        d_err "wofi is not installed (run scripts/10-sway-core.sh)."
        return 1
    fi
    wofi --show dmenu --insensitive --prompt "$1" 2>/dev/null
}

# set_marker <key> <value>
set_marker() { printf '%s\n' "$2" > "$DS_STATE/$1"; }
get_marker() { [ -f "$DS_STATE/$1" ] && cat "$DS_STATE/$1" || true; }

# reset_terminal_colors — restore a sane terminal if a command mangled it
reset_terminal_colors() { tput sgr0 2>/dev/null || true; }