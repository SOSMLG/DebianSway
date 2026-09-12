#!/usr/bin/env bash
# DEBSWAY_DESC: Fully-suited dev station (TUI tools + C/C++ + Python, no editor)
# DEBSWAY_DEFAULT: Y
# =======================================================
# Dev Essentials — fully-suited dev station (optional, no editor)
# -------------------------------------------------------
# TUI-first tooling plus editor-free language runtimes:
#   TUI:    btop (system monitor), eza (modern ls),
#           bat (pimped cat), zoxide (smart cd), yazi
#           (terminal file manager, pairs with Thunar),
#           pass (+ pass-otp, GPG-native) and/or KeePassXC
#           (GUI fallback)
#   C/C++:  build-essential (gcc/g++/make), gdb, clangd,
#           clang-format, cmake
#   Python: python3, pip, venv + scientific stack (numpy,
#           matplotlib, scipy, pandas) + requests + pytest
# Debian APT packages only — no `pip --break-system-packages`,
# no editor install. Pair with Neovim (46-neovim.sh) or
# VSCodium (40-vscodium.sh) if you want an IDE on top.
# No editor here on purpose: install Neovim + LazyVim yourself
# so your ~/.config/nvim stays yours (a toolkit-owned bootstrap
# would block LazyVim).
# Idempotent — skips anything already installed.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Dev Essentials"

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

# ---------------------------------------------------------------------------
# 3. C/C++ toolchain — compiler, debugger, language server, formatter, build
# ---------------------------------------------------------------------------
if ask "Install C/C++ toolchain (build-essential, gdb, clangd, clang-format, cmake)?" "N"; then
    install_pkgs "C/C++ toolchain" build-essential gdb clangd clang-format cmake
fi

# ---------------------------------------------------------------------------
# 4. Python toolchain + scientific stack — interpreter, pip/venv, numpy,
#    matplotlib, scipy, pandas, requests, pytest (all Debian APT packages)
# ---------------------------------------------------------------------------
if ask "Install Python toolchain + scientific libs (numpy, matplotlib, scipy, pandas, requests, pytest)?" "N"; then
    install_pkgs "Python toolchain" python3 python3-pip python3-venv \
        python3-numpy python3-matplotlib python3-scipy python3-pandas \
        python3-requests python3-pytest
fi

echo -e "${GREEN}Dev essentials complete.${NC}"
