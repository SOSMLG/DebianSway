#!/usr/bin/env bash
# =======================================================
# Python Symlink Fix for Geany & Script Runners
# -------------------------------------------------------
# Creates /usr/bin/python symlink pointing to python3
# This fixes "python: not found" in Geany and scripts
# =======================================================
set -e

# Colors
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[0m"

# Functions
info() { echo -e "${BLUE}[INFO]${CYAN} $1"; }
ok() { echo -e "${GREEN}[✔]${CYAN} $1"; }
warn() { echo -e "${YELLOW}[!]${CYAN} $1"; }

# Header
echo -e "${BLUE}===== Python Symlink Fix =====${CYAN}\n"

# Check if already exists
if [[ -L /usr/bin/python ]]; then
    warn "Symlink /usr/bin/python already exists"
    readlink /usr/bin/python
else
    info "Creating /usr/bin/python symlink..."
    sudo ln -s /usr/bin/python3 /usr/bin/python
    ok "Symlink created: /usr/bin/python → /usr/bin/python3"
fi

# Verify
info "Verifying python command..."
python --version
ok "Python symlink working!"

echo ""
echo -e "${YELLOW}Fixed:${CYAN}"
echo "  • Geany scripts using 'python' will now work"
echo "  • Any script calling 'python' will use python3"
echo "  • No more 'python: not found' errors"
echo ""
