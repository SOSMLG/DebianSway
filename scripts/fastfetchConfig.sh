#!/usr/bin/env bash
# =======================================================
# fastfetch
# -------------------------------------------------------
# System info on terminal open. Deploys the toolkit's own
# clean config, with an option to also pull extra presets
# from the butterscripts repo.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [ "$(id -u)" -eq 0 ]; then
    log_err "Do not run this as root."
    exit 1
fi

if ! command -v sudo &>/dev/null; then
    log_err "sudo not found."
    exit 1
fi

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} fastfetch${NC}"
echo -e "${CYAN}=========================================================${NC}"

# ---------------------------------------------------------------------------
# 1. Install fastfetch
# ---------------------------------------------------------------------------
if is_installed fastfetch; then
    log_ok "fastfetch already installed."
else
    log_info "Updating package lists..."
    apt_update -qq
    if sudo apt-get install -y fastfetch; then
        log_ok "fastfetch installed."
    else
        log_err "Failed to install fastfetch."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 2. Deploy the toolkit's default config
# ---------------------------------------------------------------------------
FF_DIR="$HOME/.config/fastfetch"
mkdir -p "$FF_DIR"

LOCAL_CFG="$SCRIPT_DIR/../configs/fastfetch/config.jsonc"
if [ -f "$LOCAL_CFG" ]; then
    if cp "$LOCAL_CFG" "$FF_DIR/config.jsonc"; then
        log_ok "Default config deployed to $FF_DIR/config.jsonc"
    else
        log_warn "Failed to copy default config."
    fi
else
    log_warn "Local config not found at $LOCAL_CFG — skipping default config."
fi

# ---------------------------------------------------------------------------
# 3. Optional: pull extra presets from butterscripts
# ---------------------------------------------------------------------------
if ask "Also pull extra presets (minimal/fancy/neon/debian-red/justaguy/server)?"; then
    BASE_URL="https://codeberg.org/justaguylinux/butterscripts/raw/branch/main/fastfetch"

    for f in minimal.jsonc fancy.jsonc neon.jsonc debian-red.jsonc justaguy.jsonc server.jsonc; do
        if wget -q "$BASE_URL/$f" -O "$FF_DIR/$f"; then
            log_info "  fetched $f"
        else
            log_warn "  failed to fetch $f (continuing)"
        fi
    done

    for img in debian_swirl.png justaguylinux.png; do
        wget -q "$BASE_URL/$img" -O "$FF_DIR/$img" || log_warn "  failed to fetch $img (continuing)"
    done

    log_ok "Extra presets installed to $FF_DIR"
    log_info "Switch presets: cp ~/.config/fastfetch/<preset>.jsonc ~/.config/fastfetch/config.jsonc"
fi

log_ok "fastfetch setup complete. Try it: fastfetch"
