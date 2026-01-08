#!/usr/bin/env bash
# =======================================================
# Discord & Telegram Installer for Debian 13
# -------------------------------------------------------
# Installs Discord (.deb) and Telegram (AppImage)
# =======================================================
if [ "$EUID" -ne 0 ]; then
    echo
    read -p "Press Enter to continue and enter your sudo password... " _
    sudo -k  # force password prompt
    exec sudo bash "$0" "$@"   # re-run script as root, preserving args
fi
set -euo pipefail
# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[0m"
# Functions
log_info() { echo -e "${BLUE}[INFO]${CYAN} $1"; }
log_ok() { echo -e "${GREEN}[✔]${CYAN} $1"; }
log_warn() { echo -e "${YELLOW}[!]${CYAN} $1"; }
log_err() { echo -e "${RED}[✗]${CYAN} $1"; }
# Header
echo -e "${BLUE}===== Discord & Telegram Installer =====${CYAN}\n"
log_info "Starting installation..."
# Get the actual user (even when run with sudo)
SUDO_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo ~$SUDO_USER)
# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
log_ok "Temporary directory created"
# ============================================
# Discord Installation
# ============================================
log_info "Installing Discord..."
DISCORD_URL="https://discord.com/api/download?platform=linux&format=deb"
if wget -O "$TEMP_DIR/discord.deb" "$DISCORD_URL" 2>/dev/null; then
    if apt install -y "$TEMP_DIR/discord.deb" > /dev/null 2>&1; then
        log_ok "Discord installed successfully"
    else
        log_warn "Discord installation had issues"
    fi
else
    log_err "Failed to download Discord"
fi
# ============================================
# Telegram Installation
# ============================================
log_info "Installing Telegram..."
TELEGRAM_URL="https://telegram.org/dl/desktop/linux"
if wget -O "$TEMP_DIR/telegram.tar.xz" "$TELEGRAM_URL" 2>/dev/null; then
    mkdir -p "$USER_HOME/.local/opt"
    if tar -xf "$TEMP_DIR/telegram.tar.xz" -C "$USER_HOME/.local/opt" 2>/dev/null; then
        chmod +x "$USER_HOME/.local/opt/Telegram/Telegram"
        log_ok "Telegram extracted and configured"
    else
        log_err "Failed to extract Telegram"
    fi
else
    log_err "Failed to download Telegram"
fi
# ============================================
# Create Symlink & Desktop Entry
# ============================================
log_info "Creating symlink and desktop entry..."
mkdir -p "$USER_HOME/.local/bin"
ln -sf "$USER_HOME/.local/opt/Telegram/Telegram" "$USER_HOME/.local/bin/telegram" 2>/dev/null || log_warn "Symlink update skipped"
# Create desktop entry for Telegram
mkdir -p "$USER_HOME/.local/share/applications"
cat > "$USER_HOME/.local/share/applications/telegram.desktop" << 'EOF'
[Desktop Entry]
Name=Telegram
Comment=Fast and secure messaging app
Exec=$HOME/.local/bin/telegram
Icon=telegram
Type=Application
Categories=Network;InstantMessaging;
Terminal=false
EOF
# Fix permissions
chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.local/opt" "$USER_HOME/.local/bin" "$USER_HOME/.local/share/applications" 2>/dev/null
log_ok "Desktop entries created"
# ============================================
# Completion
# ============================================
echo
log_ok "Installation complete!"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CYAN}"
log_info "Discord: Installed via .deb"
log_info "Telegram: \$HOME/.local/bin/telegram"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${CYAN}"
log_info "Both applications should now appear in your application menu"
echo
