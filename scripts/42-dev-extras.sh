#!/usr/bin/env bash
# DEBSWAY_DESC: TUI essentials (btop/eza/bat/zoxide/yazi) + Neovim + pass/KeePassXC
# DEBSWAY_DEFAULT: Y
# =======================================================
# Dev Tools Extras — TUI-first tooling for the nerd-terminal workflow
# -------------------------------------------------------
# btop (system monitor), eza (modern ls), bat (pimped cat),
# zoxide (smart cd), yazi (terminal file manager, pairs with Thunar),
# Neovim + lazy.nvim (editor — minimal bootstrap to learn on),
# pass (+ pass-otp, GPG-native) and/or KeePassXC (GUI fallback).
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
# 2. Neovim + lazy.nvim bootstrap (minimal, learn-friendly)
# ---------------------------------------------------------------------------
# Bare plugin manager + commented examples (catppuccin/treesitter/lsp) so
# learning means uncommenting, not deleting a 500-line distro.
if ask "Install Neovim + lazy.nvim plugin manager?"; then
    install_pkgs "Neovim" neovim

    if is_installed neovim && command -v nvim >/dev/null 2>&1; then
        NVIM_CONFIG="$HOME/.config/nvim"
        if [ ! -f "$NVIM_CONFIG/lua/config/lazy.lua" ]; then
            mkdir -p "$NVIM_CONFIG/lua/config"
            cat > "$NVIM_CONFIG/lua/config/lazy.lua" << 'EOF'
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- Add plugins here. Example:
    -- { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
    -- { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
    -- { "neovim/nvim-lspconfig" },
})
EOF
            cat > "$NVIM_CONFIG/init.lua" << 'EOF'
require("config.lazy")
EOF
            log_ok "Neovim configured with lazy.nvim ($NVIM_CONFIG)."
        else
            log_ok "Neovim lazy.nvim config already present."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 3. Password managers — pass (TUI/GPG-native) and/or KeePassXC (GUI)
# ---------------------------------------------------------------------------
if ask "Install pass + pass-otp (terminal password manager)?" "N"; then
    install_pkgs "pass" pass pass-otp
fi

if ask "Install KeePassXC (GUI password manager)?" "N"; then
    install_pkgs "KeePassXC" keepassxc
fi

echo -e "${GREEN}Dev tools extras complete.${NC}"