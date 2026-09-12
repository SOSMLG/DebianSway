#!/usr/bin/env bash
# DEBSWAY_DESC: TUI essentials (btop/eza/bat/zoxide/yazi) + pass/KeePassXC
# DEBSWAY_DEFAULT: Y
# =======================================================
# Dev Tools Extras — TUI-first tooling for the nerd-terminal workflow
# -------------------------------------------------------
# btop (system monitor), eza (modern ls), bat (pimped cat),
# zoxide (smart cd), yazi (terminal file manager, pairs with Thunar),
# pass (+ pass-otp, GPG-native) and/or KeePassXC (GUI fallback).
# No editor here on purpose: install Neovim + LazyVim yourself so your
# ~/.config/nvim stays yours (a toolkit-owned bootstrap would block LazyVim).
# Idempotent — skips anything already installed.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Dev Tools Extras"

log_info "Refreshing package lists..."
apt_update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Terminal tooling — btop, eza, bat, zoxide, yazi (TUI essentials)
# ---------------------------------------------------------------------------
if ask "Install terminal tooling (btop, eza, bat, zoxide, yazi)?"; then
    install_pkgs "Terminal tooling" btop eza bat zoxide yazi
fi

# ---------------------------------------------------------------------------
# 2. Password managers — pass (TUI/GPG-native) and/or KeePassXC (GUI)
# ---------------------------------------------------------------------------
if ask "Install pass + pass-otp (terminal password manager)?" "N"; then
    install_pkgs "pass" pass pass-otp
fi

if ask "Install KeePassXC (GUI password manager)?" "N"; then
    install_pkgs "KeePassXC" keepassxc
fi

echo -e "${GREEN}Dev tools extras complete.${NC}"