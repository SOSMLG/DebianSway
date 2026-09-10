#!/usr/bin/env bash
# =======================================================
# DebSway CLI — install the `debsway` command + theme engine
# -------------------------------------------------------
# Mirrors Omarchy's CLI approach: one `debsway <group> <action>`
# router (debsway/bin/debsway) dispatching to lib/ once, with
# themes/<name>/palette.sh palettes compiled into every app.
#
#   debsway menu|launcher|style|theme|bg|power|lock|agent
#   debsway clip|shot|sound|wire|toggle|calc|date|status|bar|update|doctor
#
# Installs to:
#   ~/.local/share/debsway/           the tree (bin/, lib/, themes/)
#   ~/.local/bin/debsway              user bin symlink
#   /usr/local/bin/debsway            system symlink (so sway's `exec debsway …`
#                                     binds resolve regardless of login PATH)
#
# Then applies the default theme (catppuccin-mocha-red) so the live session
# picks up the palette, and soft-reloads sway/waybar/mako/swayosd.
#
# Idempotent: safe to re-run; re-applies the tree + default theme each time.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "DebSway CLI + theme engine"

SRC="$SCRIPT_DIR/../debsway"
if [ ! -d "$SRC" ] || [ ! -f "$SRC/bin/debsway" ]; then
    log_err "Missing debsway tree at $SRC — nothing to install."
    exit 1
fi

INSTALL_DIR="$HOME/.local/share/debsway"
BIN_DIR="$HOME/.local/bin"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/debsway"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$STATE_DIR"

# ---------------------------------------------------------------------------
# 1. Copy the tree (overlay; lib + themes refresh)
# ---------------------------------------------------------------------------
log_info "Installing debsway to $INSTALL_DIR ..."
cp -r "$SRC/." "$INSTALL_DIR/"
find "$INSTALL_DIR/bin" -name 'debsway' -exec chmod +x {} +
log_ok "  tree copied (bin/, lib/, themes/)."

# ---------------------------------------------------------------------------
# 2. Symlinks — user + system (for sway binds)
# ---------------------------------------------------------------------------
if [ -x "$INSTALL_DIR/bin/debsway" ]; then
    ln -sf "$INSTALL_DIR/bin/debsway" "$BIN_DIR/debsway"
    log_ok "  ~/.local/bin/debsway → $INSTALL_DIR/bin/debsway"
    sudo ln -sf "$INSTALL_DIR/bin/debsway" /usr/local/bin/debsway 2>/dev/null || true
    if [ -e /usr/local/bin/debsway ]; then
        log_ok "  /usr/local/bin/debsway → $INSTALL_DIR/bin/debsway (sway binds can exec it)"
    else
        log_warn "  could not create /usr/local/bin/debsway — sway binds may need a relogin first."
    fi
else
    log_err "$INSTALL_DIR/bin/debsway is not executable."
    exit 1
fi

# ---------------------------------------------------------------------------
# 3. Render + apply the default theme (renders templates into ~/.config)
# ---------------------------------------------------------------------------
log_info "Applying default theme (catppuccin-mocha-red)..."
if DEBSWAY_HOME="$INSTALL_DIR" "$INSTALL_DIR/bin/debsway" theme set catppuccin-mocha-red; then
    log_ok "Theme applied and persisted (marker: $(cat "$STATE_DIR/theme" 2>/dev/null))."
else
    log_warn "Theme apply reported issues — check ~/.local/state/debsway/ and re-run."
fi

# ---------------------------------------------------------------------------
# 4. Live-session refresh
# ---------------------------------------------------------------------------
if command -v swaymsg >/dev/null 2>&1 && [ -n "${SWAYSOCK:-}" ] \
    && swaymsg -t get_version >/dev/null 2>&1; then
    swaymsg reload >/dev/null 2>&1 && log_ok "Sway reloaded."
    pkill -x waybar 2>/dev/null; sleep 0.3
    command -v waybar >/dev/null 2>&1 && setsid --fork waybar >/dev/null 2>&1 &
else
    log_info "No live sway session — everything takes effect on next login."
fi

echo
log_ok "DebSway CLI installed."
log_info "Try: debsway doctor   (\$mod+Shift+C to reload sway binds first)"
log_info "     debsway theme list / debsway style   — swap palettes live"
log_info "     debsway setup    — first-run wizard (wallpaper, night-light…)"

# ---------------------------------------------------------------------------
# ensure ~/.local/bin is on PATH for interactive shells (25 does this too;
# safe to repeat — grep-guard keeps ~/.profile tidy)
# ---------------------------------------------------------------------------
if ! grep -qF '~/.local/bin' "$HOME/.profile" 2>/dev/null \
    && ! grep -qF '.local/bin' "$HOME/.profile" 2>/dev/null; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.profile"
    log_ok "Added ~/.local/bin to PATH in ~/.profile."
fi