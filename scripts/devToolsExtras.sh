#!/usr/bin/env bash
# =======================================================
# Dev Tools Extras — nicer terminal + editor tooling
# -------------------------------------------------------
# btop (system monitor), eza (modern ls), bat (pimped cat),
# zoxide (smart cd), Neovim + lazy.nvim (editor), KeePassXC
# (password manager).
# All optional. Idempotent — skips anything already installed.
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
# 1. Terminal tooling — btop, eza, bat, zoxide (apt or cargo fallback)
# ---------------------------------------------------------------------------
if ask "Install terminal tooling (btop, eza, bat, zoxide)?" "N"; then
    install_pkgs "Terminal tooling" btop eza bat zoxide
fi

# ---------------------------------------------------------------------------
# 2. Neovim + lazy.nvim bootstrap (minimal, plugin-managed)
# ---------------------------------------------------------------------------
if ask "Install Neovim + lazy.nvim plugin manager?" "N"; then
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
# 3. KeePassXC — password manager (native, works great on Wayland)
# ---------------------------------------------------------------------------
if ask "Install KeePassXC (password manager)?" "N"; then
    install_pkgs "KeePassXC" keepassxc
fi

echo -e "${GREEN}Dev tools extras complete.${NC}"