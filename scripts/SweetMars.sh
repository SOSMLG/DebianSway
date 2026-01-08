#!/usr/bin/env bash
set -euo pipefail

# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $1"; }

# Directories
THEMEDIR="$HOME/.local/share/themes"
KVANTUMDIR="$HOME/.config/Kvantum"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Ensure ~/.local/share exists and is writable
if [ ! -d "$HOME/.local/share" ]; then
    info "Creating ~/.local/share directory..."
    mkdir -p "$HOME/.local/share"
fi

# Ensure ~/.local/share/themes exists and is writable
if [ ! -d "$THEMEDIR" ]; then
    info "Creating $THEMEDIR directory..."
    mkdir -p "$THEMEDIR"
fi

# Ensure ~/.config/Kvantum exists and is writable
if [ ! -d "$KVANTUMDIR" ]; then
    info "Creating $KVANTUMDIR directory..."
    mkdir -p "$KVANTUMDIR"
fi

# Download Sweet-Ambar-v40 theme
info "Downloading Sweet-Ambar-v40 theme..."
wget https://github.com/EliverLara/Sweet/releases/download/v6.0/Sweet-Ambar-v40.tar.xz -O "$TEMP_DIR/Sweet-Ambar-v40.tar.xz"

# Extract to temp directory first
info "Extracting theme..."
tar -xf "$TEMP_DIR/Sweet-Ambar-v40.tar.xz" -C "$TEMP_DIR"

# Install GTK theme
info "Installing Sweet-Ambar-v40 GTK theme..."
if [[ -d "$TEMP_DIR/Sweet-Ambar-v40" ]]; then
    cp -r "$TEMP_DIR/Sweet-Ambar-v40" "$THEMEDIR/"
    success "GTK theme installed to: $THEMEDIR/Sweet-Ambar-v40"
else
    warn "GTK theme directory not found in archive"
fi

# Install Kvantum theme (if it exists in the archive)
info "Installing Sweet-Ambar-v40 Kvantum theme..."
if [[ -d "$TEMP_DIR/Sweet-Ambar-v40/Kvantum" ]]; then
    cp -r "$TEMP_DIR/Sweet-Ambar-v40/Kvantum/Sweet-Ambar-v40" "$KVANTUMDIR/" 2>/dev/null || \
        warn "Kvantum theme not found in expected location"
    success "Kvantum theme installed to: $KVANTUMDIR/"
else
    warn "No Kvantum theme found in archive"
fi

echo
success "Installation complete!"
info "Apply GTK theme via nwg-look or lxappearance"
info "Apply Kvantum theme via Kvantum Manager (kvantummanager)"
