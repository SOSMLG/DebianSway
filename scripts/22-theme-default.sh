#!/usr/bin/env bash
# DEBSWAY_DESC: Graphite Amber default theme + stock cursor
# DEBSWAY_DEFAULT: Y
# =======================================================
# Graphite Amber Sway - the toolkit's theming step.
# -------------------------------------------------------
# Legacy alias of the debsway theme engine (scripts/21-debsway-cli.sh installs
# `debsway theme set`, which is the preferred way to switch palettes). This
# script still ships the Graphite Amber default palette into the
# Sway/Waybar/Fuzzel/Foot/Mako/SwayOSD configs in configs/, uses the stock
# Adwaita cursor, and points GTK apps at a dark theme.
#
# Idempotent: re-run after adding apps to refresh the icon bits;
# the config files in configs/ are simply re-copied over.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Graphite Amber Sway theme"

CONFIGS_SRC="$SCRIPT_DIR/../configs"

# ---------------------------------------------------------------------------
# 1. Bake the themed configs into ~/.config (safe overlay, nothing deleted)
# ---------------------------------------------------------------------------
if [ -d "$CONFIGS_SRC" ]; then
    log_info "Applying Graphite Amber default configs from $CONFIGS_SRC"
    for d in sway waybar fuzzel foot mako swayosd wlogout kanshi gammastep mpv xfce4 fastfetch; do
        if [ -d "$CONFIGS_SRC/$d" ]; then
            mkdir -p "$HOME/.config/$d"
            cp -r "$CONFIGS_SRC/$d/." "$HOME/.config/$d/"
            log_ok "  ~/.config/$d"
        fi
    done
else
    log_warn "configs/ not found next to scripts/ - nothing to theme."
fi

# ---------------------------------------------------------------------------
# 2. Stock cursor theme (Adwaita) - no downloaded cursor pack
# ---------------------------------------------------------------------------
CURSOR_THEME="Adwaita"
SWAY_CONFIG="$HOME/.config/sway/config"
if [ -f "$SWAY_CONFIG" ]; then
    if grep -qE '^[[:space:]]*seat[[:space:]]+\*[[:space:]]+xcursor_theme[[:space:]]' "$SWAY_CONFIG" 2>/dev/null; then
        sed -i -E "s|^[[:space:]]*seat[[:space:]]+\\*[[:space:]]+xcursor_theme[[:space:]]+.*|seat * xcursor_theme $CURSOR_THEME 24|" "$SWAY_CONFIG"
        log_ok "Sway seat uses the stock $CURSOR_THEME cursor."
    else
        printf '\n# Stock cursor theme (set by 22-theme-default.sh)\nseat * xcursor_theme %s 24\n' "$CURSOR_THEME" >> "$SWAY_CONFIG"
        log_ok "Sway seat now uses the stock $CURSOR_THEME cursor (reload: \$mod+Shift+C)."
    fi
fi

# ---------------------------------------------------------------------------
# 3. GTK apps - dark theme + stock cursor (dconf/gsettings works under
#    sway for GTK apps; no daemon needed for these keys).
# ---------------------------------------------------------------------------
if command_exists gsettings; then
    # Only set when something else hasn't deliberately overridden them.
    export GSETTINGS_BACKEND=dconf
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" 2>/dev/null || true
    log_ok "GTK interface: prefer-dark + Adwaita-dark + $CURSOR_THEME cursor."
else
    log_warn "gsettings not available - GTK apps keep their stock theme (non-fatal)."
fi

# ---------------------------------------------------------------------------
# 4. Refresh icon caches so fuzzel/waybar show proper app icons
# ---------------------------------------------------------------------------
if command_exists gtk-update-icon-cache; then
    update_dirs=$(find "$HOME/.local/share/icons" "$XDG_DATA_HOME/icons" -maxdepth 1 -type d 2>/dev/null | sort -u)
    for d in $update_dirs; do
        gtk-update-icon-cache -f "$d" >/dev/null 2>&1 || true
    done
fi

echo
log_ok "Graphite Amber Sway theme applied."
log_warn "A relogin (or \$mod+Shift+C for sway) picks up the new cursor + configs."
