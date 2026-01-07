#!/usr/bin/env bash
set -euo pipefail

# Directories
THEMEDIR="$HOME/.local/share/themes"
KVANTUMDIR="$HOME/.config/Kvantum"
mkdir -p "$THEMEDIR"
mkdir -p "$KVANTUMDIR"

# Download Sweet-Ambar-v40 theme
echo "Downloading Sweet-Ambar-v40 theme..."
wget https://github.com/EliverLara/Sweet/releases/download/v6.0/Sweet-Ambar-v40.tar.xz -P /tmp/

# Extract GTK theme
echo "Installing Sweet-Ambar-v40 GTK theme to $THEMEDIR..."
tar -xf /tmp/Sweet-Ambar-v40.tar.xz -C "$THEMEDIR"

# Extract Kvantum theme
echo "Installing Sweet-Ambar-v40 Kvantum theme to $KVANTUMDIR..."
tar -xf /tmp/Sweet-Ambar-v40.tar.xz -C "$KVANTUMDIR"

echo "Done!"
echo "GTK theme installed to: $THEMEDIR/Sweet-Ambar-v40"
echo "Kvantum theme installed to: $KVANTUMDIR/Sweet-Ambar-v40"
echo "Apply GTK theme via GNOME Tweaks or lxappearance."
echo "Apply Kvantum theme via Kvantum Manager."
