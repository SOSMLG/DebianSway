#!/usr/bin/env bash
# =======================================================
# Useful apps — media, archives, battery management
# -------------------------------------------------------
# VLC as the default media player, archive format support,
# and TLP for laptop battery/power management.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} Useful Apps${NC}"
echo -e "${CYAN}=========================================================${NC}"

log_info "Refreshing package lists..."
apt_update || { log_err "apt-get update failed, aborting."; exit 1; }

if ask "Install VLC (media player)?"; then
    install_pkgs "VLC" vlc

    if is_installed vlc && command -v xdg-mime >/dev/null 2>&1; then
        log_info "Setting VLC as the default player for common video/audio types..."
        if xdg-mime default vlc.desktop \
            video/mp4 video/x-matroska video/webm video/x-msvideo video/quicktime video/mpeg \
            audio/mpeg audio/mp4 audio/flac audio/x-wav audio/ogg 2>/dev/null; then
            log_ok "VLC set as default for common video/audio types."
        else
            log_warn "Could not set MIME defaults (non-fatal — set manually via right-click > Open With if needed)."
        fi
    fi
fi

if ask "Install archive format support (7z, rar)?"; then
    if check_repo_package unrar "non-free"; then
        install_pkgs "Archive support" p7zip-full unrar
    else
        log_warn "unrar (non-free) not in repos — using unrar-free instead."
        install_pkgs "Archive support" p7zip-full unrar-free
    fi
fi

if ask "Install TLP (laptop battery/power management)?" "N"; then
    if is_installed power-profiles-daemon; then
        log_info "power-profiles-daemon conflicts with TLP — removing it first."
        start_service power-profiles-daemon stop 2>/dev/null || true
        sudo apt-get purge -y power-profiles-daemon 2>/dev/null || log_warn "Couldn't remove power-profiles-daemon."
    fi

    install_pkgs "TLP" tlp tlp-rdw
    if is_installed tlp; then
        start_service tlp
        log_ok "TLP installed and running. Check status: sudo tlp-stat -s"

        BAT_PATH=$(find /sys/class/power_supply -maxdepth 1 -iname 'BAT*' -print -quit 2>/dev/null)
        if [ -n "$BAT_PATH" ] && [ -f "${BAT_PATH}/charge_control_end_threshold" ]; then
            BAT_NAME=$(basename "$BAT_PATH")
            log_info "Charge-threshold support detected on ${BAT_NAME}."
            if ask "Cap charging at 80% to slow battery wear?" "N"; then
                sudo mkdir -p /etc/tlp.d
                sudo tee /etc/tlp.d/60-battery-threshold.conf > /dev/null << EOF
# Written by usefulApps.sh — charge threshold for ${BAT_NAME}.
START_CHARGE_THRESH_${BAT_NAME}=75
STOP_CHARGE_THRESH_${BAT_NAME}=80
EOF
                sudo tlp start >/dev/null 2>&1 || true
                log_ok "Charge capped at 80% (resumes below 75%)."
            fi
        else
            log_info "No charge-threshold sysfs entry found — nothing to configure."
        fi
    fi
fi

echo -e "${GREEN}Useful apps step complete.${NC}"
