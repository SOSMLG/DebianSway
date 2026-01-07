#!/usr/bin/env bash
set -euo pipefail

# Directories
THEMEDIR="$HOME/.local/share/themes"
KVANTUMDIR="$HOME/.config/Kvantum"
mkdir -p "$THEMEDIR"
mkdir -p "$KVANTUMDIR"

# Sweet-Mars (red) theme
GIT_REPO="https://github.com/EliverLara/Sweet.git"
THEME_NAME="Sweet-Ambar-v40"

# Clone GTK theme
echo "Installing Sweet-Mars (red) GTK theme to $THEMEDIR..."
git clone "$GIT_REPO" "$THEMEDIR/$THEME_NAME"

# Clone Kvantum theme for Qt apps
echo "Installing Sweet-Mars (red) Kvantum theme to $KVANTUMDIR..."
git clone "$GIT_REPO" "$KVANTUMDIR/$THEME_NAME"

echo "Done!"
echo "GTK theme installed to: $THEMEDIR/$THEME_NAME"
echo "Kvantum theme installed to: $KVANTUMDIR/$THEME_NAME"
echo "Apply GTK theme via GNOME Tweaks or lxappearance."
echo "Apply Kvantum theme via Kvantum Manager."
