#!/bin/bash

# Script to install Discord (.deb) and Telegram (AppImage) on Debian 13
# Run with: bash install_discord_telegram.sh

set -e  # Exit on error

if [ "$EUID" -ne 0 ]; then
    echo "This script will make system-wide changes and requires administrator (root) privileges."
    echo
    read -p "Press Enter to continue and enter your sudo password... " _
    sudo -k    # invalidate existing timestamp to force password prompt
    exec sudo bash "$0" "$@"   # re-run script as root, preserving args
fi

echo "=== Installing Discord and Telegram on Debian 13 ==="

# Create a temporary directory for downloads
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Install Discord from .deb
echo "Downloading Discord..."
DISCORD_URL="https://discord.com/api/download?platform=linux&format=deb"
wget -O "$TEMP_DIR/discord.deb" "$DISCORD_URL"

echo "Installing Discord..."
sudo apt install -y "$TEMP_DIR/discord.deb"

# Install Telegram via official tarball
echo "Downloading Telegram..."
TELEGRAM_URL="https://telegram.org/dl/desktop/linux"
wget -O "$TEMP_DIR/telegram.tar.xz" "$TELEGRAM_URL"

echo "Extracting and installing Telegram..."
mkdir -p "$HOME/.local/opt"
tar -xf "$TEMP_DIR/telegram.tar.xz" -C "$HOME/.local/opt"
chmod +x "$HOME/.local/opt/Telegram/Telegram"

# Create symlink in bin
mkdir -p "$HOME/.local/bin"
ln -sf "$HOME/.local/opt/Telegram/Telegram" "$HOME/.local/bin/telegram"

# Create desktop entry for Telegram so it shows in app menus
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/telegram.desktop" << 'EOF'
[Desktop Entry]
Name=Telegram
Exec=$HOME/.local/bin/telegram
Icon=telegram
Type=Application
Categories=Network;InstantMessaging;
EOF

echo "=== Installation Complete ==="
echo "Discord has been installed via .deb"
echo "Telegram AppImage is at: $HOME/.local/bin/telegram"
echo "Both should now appear in your application menu"
