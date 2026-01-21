#!/usr/bin/env bash
# =======================================================
# Debian 13 Gaming & Wayland Setup (Minimal)
# -------------------------------------------------------
# Installs Steam, Heroic, and configures Wayland scaling
# =======================================================

if [ "$EUID" -ne 0 ]; then
    echo
    read -p "Press Enter to continue and enter your sudo password... " _
    sudo -k
    exec sudo bash "$0" "$@"
fi

set -euo pipefail

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"

# Functions
log_info() { echo -e "${BLUE}[INFO]${RESET} $1"; }
log_ok() { echo -e "${GREEN}[✓]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[!]${RESET} $1"; }
log_err() { echo -e "${RED}[✗]${RESET} $1"; }

# Header
echo -e "${BLUE}===== Debian 13 Gaming & General Setup =====${RESET}\n"
log_info "Starting setup..."

# Update
log_info "Updating system..."
apt update > /dev/null 2>&1
apt upgrade -y > /dev/null 2>&1
log_ok "System updated"

# 32-bit support
log_info "Enabling 32-bit support..."
dpkg --add-architecture i386 > /dev/null 2>&1
apt update > /dev/null 2>&1
log_ok "32-bit enabled"

# Core packages
log_info "Installing gaming dependencies..."
PACKAGES=(
    "libvulkan1" "libvulkan1:i386"
    "mesa-utils"
    "gamemode" "mangohud"
)

failed_packages=()
for pkg in "${PACKAGES[@]}"; do
    if ! apt install -y "$pkg" > /dev/null 2>&1; then
        failed_packages+=("$pkg")
        log_warn "Failed to install: $pkg"
    fi
done

if [[ ${#failed_packages[@]} -eq 0 ]]; then
    log_ok "All gaming dependencies installed"
else
    log_warn "Some packages failed: ${failed_packages[*]}"
fi

# Steam
log_info "Installing Steam..."
if command -v steam &>/dev/null; then
    log_warn "Steam already installed"
else
    cd /tmp
    if curl -L -o steam.deb https://repo.steampowered.com/steam/archive/precise/steam_latest.deb 2>/dev/null; then
        if apt install -y ./steam.deb > /dev/null 2>&1; then
            log_ok "Steam installed"
        else
            log_err "Steam installation failed"
        fi
        rm -f steam.deb
    else
        log_err "Could not download Steam"
    fi
fi

# Heroic
log_info "Installing Heroic Launcher..."
HEROIC_URL=$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest 2>/dev/null | grep "\.deb" | grep "browser_download_url" | cut -d'"' -f4 | head -1)

if [[ -n "$HEROIC_URL" ]]; then
    cd /tmp
    if curl -L -o heroic.deb "$HEROIC_URL" 2>/dev/null; then
        if apt install -y ./heroic.deb > /dev/null 2>&1; then
            log_ok "Heroic installed"
        else
            log_err "Heroic installation failed"
        fi
        rm -f heroic.deb
    else
        log_err "Could not download Heroic"
    fi
else
    log_err "Could not fetch Heroic download URL"
fi

# User setup
SUDO_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo ~$SUDO_USER)
log_info "Configuring for user: $SUDO_USER"

# Environment variables
ENV_FILE="$USER_HOME/.profile"
if ! grep -q "Wayland Gaming" "$ENV_FILE" 2>/dev/null; then
    cat >> "$ENV_FILE" << 'EOF'

# Wayland Gaming Optimization
export GDK_SCALE=1 GDK_DPI_SCALE=1
export QT_AUTO_SCREEN_SCALE_FACTOR=0 QT_SCALE_FACTOR=1
export XWAYLAND_FORCE_SCALE=1 WAYLAND_DISPLAY=wayland-0
export SDL_VIDEODRIVER=wayland MOZ_ENABLE_WAYLAND=1
EOF
    log_ok "Environment variables added"
else
    log_warn "Environment variables already configured"
fi

# Desktop launchers
mkdir -p "$USER_HOME/.local/share/applications"

cat > "$USER_HOME/.local/share/applications/steam-opt.desktop" << 'EOF'
[Desktop Entry]
Name=Steam (Optimized)
Exec=env GDK_SCALE=1 QT_SCALE_FACTOR=1 XWAYLAND_FORCE_SCALE=1 steam
Icon=steam
Type=Application
Categories=Game;
EOF

cat > "$USER_HOME/.local/share/applications/heroic-opt.desktop" << 'EOF'
[Desktop Entry]
Name=Heroic (Optimized)
Exec=env GDK_SCALE=1 QT_SCALE_FACTOR=1 XWAYLAND_FORCE_SCALE=1 heroic
Icon=heroic
Type=Application
Categories=Game;
EOF

chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.local/share/applications" "$USER_HOME/.profile"
log_ok "Desktop shortcuts created"

# Completion
echo
log_ok "Setup complete!"
log_info "Gaming environment configured for Wayland"
log_info "Steam and Heroic are ready to use"
echo
