#!/usr/bin/env bash
# DEBSWAY_DESC: (optional) VSCodium editor
# DEBSWAY_DEFAULT: N
# =======================================================
# VSCodium (optional)
# -------------------------------------------------------
# Telemetry-free build of VS Code. Installed via the
# official VSCodium APT repository so it stays updated
# through normal `apt upgrade`, rather than a one-off
# GitHub release .deb that never updates itself.
# Source: https://vscodium.com/#install
# Releases (for reference): https://github.com/VSCodium/vscodium/releases
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} VSCodium${NC}"
echo -e "${CYAN}=========================================================${NC}"

if [[ $EUID -eq 0 ]]; then
    log_err "Do not run this as root."
    exit 1
fi

if is_installed codium; then
    log_ok "VSCodium (codium) is already installed."
    exit 0
fi

for dep in wget gnupg; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        log_info "Installing dependency: $dep"
        apt_update -qq || true
        priv apt-get install -y "$dep" || { log_err "Failed to install $dep"; exit 1; }
    fi
done

KEYRING="/usr/share/keyrings/vscodium-archive-keyring.gpg"
SOURCES_FILE="/etc/apt/sources.list.d/vscodium.list"

if [ ! -f "$KEYRING" ]; then
    log_info "Adding VSCodium's GPG key..."
    if wget -qO - "https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg" \
            | gpg --dearmor | priv tee "$KEYRING" > /dev/null; then
        # apt runs as _apt (not root): the keyring must stay world-readable.
        priv chmod 644 "$KEYRING"
        log_ok "Key installed to $KEYRING"
    else
        log_err "Failed to fetch/install the VSCodium GPG key."
        exit 1
    fi
else
    log_ok "Key already present at $KEYRING."
fi

log_info "Adding VSCodium APT repository..."
ARCH="$(dpkg --print-architecture)"
if [ ! -f "$SOURCES_FILE" ]; then
    if echo "deb [arch=${ARCH} signed-by=${KEYRING}] https://download.vscodium.com/debs vscodium main" \
            | priv tee "$SOURCES_FILE" > /dev/null; then
        log_ok "Repository added at $SOURCES_FILE (scoped to arch=${ARCH})"
    else
        log_err "Failed to write $SOURCES_FILE"
        exit 1
    fi
else
    log_ok "Repository already present at $SOURCES_FILE."
fi

log_info "Updating package lists..."
apt_update || { log_err "apt-get update failed after adding the VSCodium repo."; exit 1; }

log_info "Installing codium..."
if priv apt-get install -y codium; then
    log_ok "VSCodium installed. Launch it with 'codium'."
    # Plain-text default: opening a .txt/.log lands in the editor, and this
    # also repairs hijacks (some launchers claim text/plain).
    if command -v gio >/dev/null 2>&1; then
        gio mime text/plain codium.desktop >/dev/null 2>&1 || true
    elif command -v xdg-mime >/dev/null 2>&1; then
        xdg-mime default codium.desktop text/plain >/dev/null 2>&1 || true
    fi
else
    log_err "Failed to install codium."
    exit 1
fi
