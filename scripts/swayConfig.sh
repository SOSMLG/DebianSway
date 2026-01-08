#!/usr/bin/env bash
#============================================================#
#            Debian 13 Sway Config Setup Script             #
#      Sets up user configuration files                      #
#============================================================#

set -euo pipefail

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

# Ensure not running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should NOT be run as root/sudo"
    error "Run it as your regular user"
    exit 1
fi

# Nerd Fonts
info "Installing JetBrainsMono Nerd Font..."
mkdir -p ~/.local/share/fonts
pushd ~/.local/share/fonts > /dev/null

if [[ ! -f JetBrainsMono.tar.xz ]]; then
    curl -OL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
fi

bash -c 'mkdir -p "${1%.tar.xz}" && tar -xf "$1" -C "${1%.tar.xz}"' _ JetBrainsMono.tar.xz
rm -f JetBrainsMono.tar.xz
fc-cache -fv > /dev/null

popd > /dev/null
success "Nerd font installed!"

# Starship Prompt
info "Installing Starship prompt..."
if ! command -v starship &> /dev/null; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

if ! grep -q "starship init bash" ~/.bashrc; then
    echo 'eval "$(starship init bash)"' >> ~/.bashrc
fi
success "Starship installed!"

# fzf
info "Installing fzf..."
if [[ ! -d ~/.fzf ]]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
else
    warn "fzf already installed, skipping"
fi
success "fzf ready!"

# Sway Config
info "Copying Sway config..."
mkdir -p ~/.config/sway
if [[ -f /etc/sway/config ]]; then
    cp /etc/sway/config ~/.config/sway/config
    success "Sway config copied!"
else
    warn "System Sway config not found at /etc/sway/config"
fi

# Waybar Config
info "Copying Waybar config..."
mkdir -p ~/.config/waybar
if [[ -d /etc/xdg/waybar ]]; then
    cp -r /etc/xdg/waybar/* ~/.config/waybar/
    success "Waybar config copied!"
else
    warn "System Waybar config not found at /etc/xdg/waybar"
fi

# Create GTK theme config folders
info "Creating GTK config folders..."
mkdir -p ~/.config/{gtk-3.0,gtk-4.0}
success "GTK theme config folders created!"

# Done
echo
success "All configuration steps completed!"
info "You may need to log out and back in for all changes to take effect"
