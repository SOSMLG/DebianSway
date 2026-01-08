#!/usr/bin/env bash
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
SETUP_DIR="$SCRIPT_DIR/.config"

# Check setup folder exists
if [ ! -d "$SETUP_DIR" ]; then
    echo "Error: Setup folder $SETUP_DIR does not exist!"
    exit 1
fi

# Backup existing .config
if [ -d "$CONFIG_DIR" ]; then
    echo "Backing up existing .config to $BACKUP_DIR"
    mv "$CONFIG_DIR" "$BACKUP_DIR"
fi

mkdir -p "$CONFIG_DIR"

# Copy everything, including empty directories
echo "Copying configs from $SETUP_DIR to $CONFIG_DIR"
if command -v rsync &> /dev/null; then
    rsync -avh --progress "$SETUP_DIR/" "$CONFIG_DIR/"
else
    cp -r "$SETUP_DIR/"* "$CONFIG_DIR/"
fi

echo "✓ Done. Original configs are backed up at $BACKUP_DIR"
