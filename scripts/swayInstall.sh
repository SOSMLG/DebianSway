#!/usr/bin/env bash
#============================================================#
#            Debian 13 Sway Full Setup Script               #
#      Fully automatic, no prompts, ready for fresh system  #
#============================================================#

# Colors
RED="\033[1;31m"       
GREEN="\033[1;32m"       
YELLOW="\033[1;33m"  
BLUE="\033[1;34m"     
CYAN="\033[1;36m"
RESET="\033[0m"

info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1"; }

# Require Root
if [ "$EUID" -ne 0 ]; then
    warn "This script will make system-wide changes and requires administrator (root) privileges."
    echo
    read -p "Press Enter to continue and enter your sudo password... " _
    sudo -k
    exec sudo bash "$0" "$@"
fi

set -euo pipefail

# Get actual user
ACTUAL_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(eval echo ~$ACTUAL_USER)

info "Installing for user: $ACTUAL_USER"

# Update System
info "Updating system..."
apt update && apt upgrade -y
success "System updated!"

# Basic Tools
info "Installing essential tools..."
apt install -y zram-tools curl git wget
success "Basic tools installed!"

# Python & Dev Tools
info "Installing Python and development essentials..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    python3-numpy \
    python3-scipy \
    python3-matplotlib \
    python3-pandas
success "Python and scientific libraries installed!"

# Sway & WLR
info "Installing Sway and related packages..."
apt install -y sway swaylock swayidle swaybg sway-notification-center \
    xdg-desktop-portal-wlr xwayland xdg-desktop-portal
success "Sway installed!"

# Waybar & UI
info "Installing Waybar, brightness, audio, clipboard, notifications..."
apt install -y waybar upower brightnessctl pavucontrol cliphist \
    wl-clipboard libnotify-bin network-manager-applet autotiling 
success "Waybar and UI utilities installed!"

# File Managers
info "Installing Thunar and archive tools..."
apt install -y thunar thunar-volman thunar-archive-plugin xarchiver \
    tumbler ffmpegthumbnailer zenity rar unar zip p7zip-full p7zip-rar unzip \
    gvfs-backends gvfs-fuse smbclient mate-polkit geany geany-plugin-addons \
    geany-plugin-git-changebar geany-plugin-overview geany-plugin-spellcheck \
    geany-plugin-treebrowser geany-plugin-vimode geany-plugin-markdown \
    timeshift
success "File managers installed!"

# Media Packages
info "Installing multimedia packages..."
apt install -y ffmpeg mpv imv audacious mediainfo-gui flameshot blueman \
    shotcut audacity
success "Media packages installed!"

# Terminal Tools
info "Installing terminal tools..."
apt install -y alacritty bat duf htop eza rsync fzf zoxide
success "Terminal tools installed!"

# Rofi-Wayland
info "Downloading and installing latest Rofi-Wayland..."
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

pushd "$TMP_DIR" > /dev/null

ROFI_URL=$(curl -s https://api.github.com/repos/lbonn/rofi/releases/latest \
    | grep "browser_download_url.*\.deb" | grep -v "dbgsym" | cut -d '"' -f 4 | head -1)

if [[ -n "$ROFI_URL" ]]; then
    wget "$ROFI_URL"
    apt install -y ./*.deb
    success "Rofi-Wayland installed!"
else
    warn "Could not fetch Rofi-Wayland, installing from repos..."
    apt install -y rofi
fi

popd > /dev/null

# Greetd
info "Installing greetd..."
apt install -y greetd

GREETD_CONFIG="/etc/greetd/config.toml"
cp "$GREETD_CONFIG" "${GREETD_CONFIG}.bak"
success "Backup created at ${GREETD_CONFIG}.bak"

sed -i "s|\${SHELL:-/bin/sh}|\${SHELL:-/bin/bash}|g" "$GREETD_CONFIG"
success "Updated default shell to bash in greetd config"

cat <<GREETD_EOF >> "$GREETD_CONFIG"

[initial_session]
command = "sway"
user = "$ACTUAL_USER"
GREETD_EOF
success "Appended initial_session with user $ACTUAL_USER"

# Theme packages
info "Installing theme packages..."
apt install -y nwg-look qt5-style-kvantum qt6-style-kvantum papirus-icon-theme
success "Theme packages installed!"

# Oh my Bash (as user, not root)
info "Installing Oh My Bash for $ACTUAL_USER..."
if [[ ! -d "$USER_HOME/.oh-my-bash" ]]; then
    su - "$ACTUAL_USER" -c 'bash -c "$(wget https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh -O -)" || true'
    success "Oh My Bash installed!"
else
    warn "Oh My Bash already installed, skipping"
fi

# Done
echo
success "All installation steps completed!"
info "Please reboot your system to complete the setup"
