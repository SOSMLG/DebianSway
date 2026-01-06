#!/usr/bin/env bash
#============================================================#
#                    Vivaldi Install Script                  #
#                     For Debian-based distros               #
#============================================================#

#==================#
#   Colors Setup   #
#==================#
RED="\033[1;31m"       
GREEN="\033[0m"       
YELLOW="\033[1;33m"  
BLUE="\033[1;34m"     
CYAN="\033[0m"  

warn()  { echo -e "${YELLOW}$*${CYAN}"; }
info()  { echo -e "${BLUE}$*${CYAN}"; }
ok()    { echo -e "${GREEN}$*${CYAN}"; }

#==================#
#   Require Root   #
#==================#
if [ "$EUID" -ne 0 ]; then
    warn "This script will make system-wide changes and requires administrator (root) privileges."
    echo
    read -p "Press Enter to continue and enter your sudo password... " _
    sudo -k  # force password prompt
    exec sudo bash "$0" "$@"   # re-run script as root, preserving args
fi

set -euo pipefail

#-------------------------
# Ensure required tools
#-------------------------
info "[0/4] Ensuring required packages are present (wget, gpg)..."
if ! command -v wget >/dev/null 2>&1; then
    info "Installing wget..."
    apt update -y
    apt install -y wget
fi

if ! command -v gpg >/dev/null 2>&1; then
    info "Installing gnupg..."
    apt update -y
    apt install -y gnupg
fi

#===========================#
#   Step 1: Import Key      #
#===========================#
info "[1/4] Downloading Vivaldi APT signing key..."
wget -qO- https://repo.vivaldi.com/archive/linux_signing_key.pub | gpg --dearmor | tee /usr/share/keyrings/vivaldi.gpg > /dev/null

#===============================#
#   Step 2: Add Repository     #
#===============================#
info "[2/4] Adding Vivaldi APT repository..."
echo "deb [signed-by=/usr/share/keyrings/vivaldi.gpg arch=amd64] https://repo.vivaldi.com/archive/deb/ stable main" \
  | tee /etc/apt/sources.list.d/vivaldi.list > /dev/null

#===============================#
#   Step 3: Update APT        #
#===============================#
info "[3/4] Updating package list..."
apt update

#===========================#
#   Step 4: Install Vivaldi #
#===========================#
info "[4/4] Installing Vivaldi..."
apt install -y vivaldi-stable

ok "✓ Vivaldi installation complete!"
