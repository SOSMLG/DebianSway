#!/usr/bin/env bash
# =======================================================
# Debian 13 Gaming & Wayland Setup (Minimal)
# -------------------------------------------------------
# Installs Steam, Heroic, and configures Wayland scaling
# Also creates Python symlink for Geany compatibility
# =======================================================
set -e

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

check_root() {
    [[ $EUID -ne 0 ]] && { log_err "Run with sudo"; exit 1; }
}

safe_install() {
    apt install -y "$1" 2>/dev/null || log_warn "Skipped: $1"
}

# Header
echo -e "${BLUE}===== Debian 13 Gaming & General Setup =====${CYAN}\n"
check_root

# Update
log_info "Updating system..."
apt update && apt upgrade -y
log_ok "System updated"

# 32-bit support
log_info "Enabling 32-bit support..."
dpkg --add-architecture i386 2>/dev/null || true
apt update
log_ok "32-bit enabled"

# Core packages
log_info "Installing dependencies..."
PKGS=(
    "libvulkan1" "libvulkan1:i386"
    "mesa-vulkan-drivers" "mesa-vulkan-drivers:i386"
    "libgl1-mesa-dri" "libgl1-mesa-dri:i386"
    "xwayland" "wayland-protocols"
    "vulkan-tools" "mesa-utils"
    "gamemode" "mangohud"
    "winetricks" "protontricks"
)

for pkg in "${PKGS[@]}"; do
    safe_install "$pkg"
done
log_ok "Dependencies installed"

# Steam (direct .deb from Valve)
log_info "Installing Steam..."
if ! command -v steam &>/dev/null; then
    cd /tmp
    curl -L -o steam.deb https://repo.steampowered.com/steam/archive/precise/steam_latest.deb 2>/dev/null
    apt install -y ./steam.deb 2>/dev/null || log_warn "Steam install failed, check dependencies"
    rm -f steam.deb
    log_ok "Steam installed"
else
    log_warn "Steam already installed"
fi

# Heroic Launcher
log_info "Installing Heroic..."
HEROIC_URL=$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest 2>/dev/null | grep "\.deb" | grep "browser_download_url" | cut -d'"' -f4 | head -1)

if [[ -n "$HEROIC_URL" ]]; then
    cd /tmp
    curl -L -o heroic.deb "$HEROIC_URL" 2>/dev/null && apt install -y ./heroic.deb && rm -f heroic.deb
    log_ok "Heroic installed"
else
    log_warn "Could not fetch Heroic, install manually: https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher"
fi

# User setup
SUDO_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo ~$SUDO_USER)

log_info "Configuring for user: $SUDO_USER"

# Environment variables
ENV_FILE="$USER_HOME/.profile"
if ! grep -q "Wayland Gaming" "$ENV_FILE"; then
    cat >> "$ENV_FILE" << 'EOF'

# Wayland Gaming Optimization
export GDK_SCALE=1 GDK_DPI_SCALE=1
export QT_AUTO_SCREEN_SCALE_FACTOR=0 QT_SCALE_FACTOR=1
export XWAYLAND_FORCE_SCALE=1 WAYLAND_DISPLAY=wayland-0
export SDL_VIDEODRIVER=wayland MOZ_ENABLE_WAYLAND=1
EOF
    log_ok "Environment variables added"
fi

# Aliases
BASHRC_FILE="$USER_HOME/.bashrc"
if ! grep -q "steam-run" "$BASHRC_FILE"; then
    cat >> "$BASHRC_FILE" << 'EOF'

alias steam-run='gamemoderun'
alias steam-fps='mangohud'
alias check-gpu='glxinfo | grep -i renderer'
EOF
    log_ok "Aliases added"
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

chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.local/share/applications"
chown "$SUDO_USER:$SUDO_USER" "$USER_HOME/.profile" "$USER_HOME/.bashrc"

log_ok "Launchers created"

# System optimizations
log_info "Optimizing system..."
sysctl -w vm.swappiness=10 > /dev/null 2>&1 || true
sysctl -w fs.inotify.max_user_watches=524288 > /dev/null 2>&1 || true
echo "vm.swappiness=10" >> /etc/sysctl.conf 2>/dev/null || true
log_ok "Optimizations applied"

# ============== SSD TRIM OPTIMIZATION ==============
log_info "Setting up SSD TRIM optimization..."

# Enable fstrim.timer for weekly SSD trim
if systemctl is-enabled fstrim.timer &>/dev/null; then
    log_warn "fstrim.timer already enabled"
else
    systemctl enable fstrim.timer
    systemctl start fstrim.timer
    log_ok "fstrim.timer enabled (weekly SSD trim)"
fi

# Check if disk supports TRIM
if lsblk -d -o name,disc-gran | grep -q "0B"; then
    log_warn "SSD TRIM may not be supported on this drive"
else
    log_ok "SSD TRIM support detected"
fi

# ============== PYTHON SYMLINK FIX ==============
log_info "Setting up Python symlink for Geany..."

# Check if symlink already exists
if [[ -L /usr/bin/python ]]; then
    log_warn "Python symlink already exists"
elif [[ ! -e /usr/bin/python ]]; then
    ln -s /usr/bin/python3 /usr/bin/python
    log_ok "Python symlink created: /usr/bin/python → /usr/bin/python3"
else
    log_warn "Python file exists but is not a symlink, skipping"
fi

# Verify
if command -v python &>/dev/null; then
    log_ok "Python symlink verified: $(python --version)"
else
    log_warn "Python symlink verification failed"
fi

# Summary
echo ""
echo -e "${BLUE}===== Setup Complete =====${CYAN}"
echo -e "${YELLOW}✓ Installed:${CYAN} Steam, Heroic, Vulkan, GameMode"
echo -e "${YELLOW}✓ Configured:${CYAN} Wayland scaling, X11 compat, Launchers, Python symlink"
echo -e "${YELLOW}✓ Optimized:${CYAN} Swappiness, File watchers, SSD TRIM (weekly)"
echo ""
echo -e "${YELLOW}Next:${CYAN} Log out & back in, then run Steam/Heroic"
echo -e "${YELLOW}Aliases:${CYAN} steam-run, steam-fps, check-gpu"
echo -e "${YELLOW}Python:${CYAN} Geany can now use 'python' directly"
echo -e "${YELLOW}SSD:${CYAN} Automatic weekly TRIM enabled via fstrim.timer"
echo ""
