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

mkdir -p "$THEMEDIR"
mkdir -p "$KVANTUMDIR"

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
EOF

# ============================================
# 12. updateConfig.sh (FIXED VERSION)
# ============================================
cat > updateConfig.sh << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG_DIR="$HOME/.config"
BACKUP_BASE="$HOME/.backup"
BACKUP_DIR="$BACKUP_BASE/.config_backup_$(date +%Y%m%d_%H%M%S)"
SETUP_DIR="$SCRIPT_DIR/.config"

# Check setup folder exists
if [ ! -d "$SETUP_DIR" ]; then
    echo "Error: Setup folder $SETUP_DIR does not exist!"
    exit 1
fi

# Ensure backup directory exists
mkdir -p "$BACKUP_BASE"

# Backup existing .config
if [ -d "$CONFIG_DIR" ]; then
    echo "Backing up existing .config to $BACKUP_DIR"
    cp -a "$CONFIG_DIR" "$BACKUP_DIR"
    echo "✓ Backup created"
fi

# Copy and overwrite configs
echo "Copying configs from $SETUP_DIR to $CONFIG_DIR"
if command -v rsync &> /dev/null; then
    rsync -avh --progress "$SETUP_DIR/" "$CONFIG_DIR/"
else
    cp -r "$SETUP_DIR/"* "$CONFIG_DIR/"
fi

echo "✓ Done. Original configs are backed up at $BACKUP_DIR"
EOF

echo "All scripts have been fixed and written to individual files!"
