#!/usr/bin/env bash
# DEBSWAY_DESC: Catppuccin Mocha/Red default theme + cursor pack
# DEBSWAY_DEFAULT: Y
# =======================================================
# Catppuccin Sway — the toolkit's theming step.
# -------------------------------------------------------
# Legacy alias of the debsway theme engine (scripts/21-debsway-cli.sh installs
# `debsway theme set`, which is the preferred way to switch palettes). This
# script still ships the Catppuccin Mocha (Red accent) default palette into
# the Sway/Waybar/Wofi/Alacritty/Mako/SwayOSD configs in configs/, installs the
# Catppuccin cursor theme, and points GTK apps at a dark theme.
#
# Idempotent: re-run after adding apps to refresh the icon/cursor bits;
# the config files in configs/ are simply re-copied over.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Catppuccin Sway theme"

CONFIGS_SRC="$SCRIPT_DIR/../configs"

# ---------------------------------------------------------------------------
# 1. Bake the themed configs into ~/.config (safe overlay, nothing deleted)
# ---------------------------------------------------------------------------
if [ -d "$CONFIGS_SRC" ]; then
    log_info "Applying Catppuccin default configs from $CONFIGS_SRC"
    for d in sway waybar wofi alacritty mako swayosd wlogout kanshi gammastep; do
        if [ -d "$CONFIGS_SRC/$d" ]; then
            mkdir -p "$HOME/.config/$d"
            cp -r "$CONFIGS_SRC/$d/." "$HOME/.config/$d/"
            log_ok "  ~/.config/$d"
        fi
    done
else
    log_warn "configs/ not found next to scripts/ — nothing to theme."
fi

# ---------------------------------------------------------------------------
# 2. Catppuccin cursor theme (Mocha, Red accent) from catppuccin/cursors
# ---------------------------------------------------------------------------
CURSOR_ZIP="catppuccin-mocha-red-cursors.zip"
CURSOR_URL="https://github.com/catppuccin/cursors/releases/download/v2.0.0/${CURSOR_ZIP}"
ICONS_DIR="$HOME/.local/share/icons"
mkdir -p "$ICONS_DIR"

CURSOR_TARGET="$ICONS_DIR/Catppuccin-Mocha-Red"
if [ -d "$CURSOR_TARGET" ] && [ -f "$CURSOR_TARGET/cursor.theme" ]; then
    log_ok "Catppuccin-Red cursor already installed."
else
    WORK_DIR="$(mktemp -d)"
    trap 'rm -rf "$WORK_DIR"' EXIT

    if command_exists curl && curl -fsSL "$CURSOR_URL" -o "$WORK_DIR/$CURSOR_ZIP"; then
        verify_download "$WORK_DIR/$CURSOR_ZIP" 65536
        if unzip -qo "$WORK_DIR/$CURSOR_ZIP" -d "$WORK_DIR/cursors"; then
            if [ -d "$WORK_DIR/cursors/Catppuccin-Mocha-Red" ]; then
                cp -r "$WORK_DIR/cursors/Catppuccin-Mocha-Red" "$CURSOR_TARGET"
                log_ok "Installed Catppuccin cursor theme to $CURSOR_TARGET"
            else
                log_warn "No Catppuccin-Mocha-Red dir in the archive — leaving cursor stock."
            fi
        else
            log_warn "Could not unzip cursor archive — leaving cursor stock."
        fi
    else
        log_warn "Cursor download failed (offline or rate-limited) — leaving cursor stock."
    fi
fi

# Point sway at the cursor theme (seat section), idempotently.
SWAY_CONFIG="$HOME/.config/sway/config"
if [ -f "$SWAY_CONFIG" ] && [ -d "$CURSOR_TARGET" ]; then
    if grep -q "xcursor_theme Catppuccin" "$SWAY_CONFIG" 2>/dev/null; then
        log_ok "Sway already set to use the Catppuccin cursor."
    else
        printf '\n# Catppuccin cursor theme (set by 22-theme-default.sh)\nseat * xcursor_theme Catppuccin-Mocha-Red 24\n' >> "$SWAY_CONFIG"
        log_ok "Sway seat now uses the Catppuccin cursor (reload: \$mod+Shift+C)."
    fi
fi

# ---------------------------------------------------------------------------
# 3. GTK apps — dark theme + catppuccin cursor (dconf/gsettings works under
#    sway for GTK apps; no daemon needed for these keys).
# ---------------------------------------------------------------------------
if command_exists gsettings; then
    # Only set when something else hasn't deliberately overridden them.
    export GSETTINGS_BACKEND=dconf
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark 2>/dev/null || true
    if [ -d "$CURSOR_TARGET" ]; then
        gsettings set org.gnome.desktop.interface cursor-theme Catppuccin-Mocha-Red 2>/dev/null || true
    fi
    log_ok "GTK interface: prefer-dark + Adwaita-dark + Catppuccin cursor."
else
    log_warn "gsettings not available — GTK apps keep their stock theme (non-fatal)."
fi

# ---------------------------------------------------------------------------
# 4. Refresh icon caches so wofi/waybar show proper app icons
# ---------------------------------------------------------------------------
if command_exists gtk-update-icon-cache; then
    update_dirs=$(find "$HOME/.local/share/icons" "$XDG_DATA_HOME/icons" -maxdepth 1 -type d 2>/dev/null | sort -u)
    for d in $update_dirs; do
        gtk-update-icon-cache -f "$d" >/dev/null 2>&1 || true
    done
fi

echo
log_ok "Catppuccin Sway theme applied."
log_warn "A relogin (or \$mod+Shift+C for sway) picks up the new cursor + configs."