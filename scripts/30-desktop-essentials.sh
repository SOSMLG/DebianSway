#!/usr/bin/env bash
# DEBSWAY_DESC: Flatpak/Flathub, CUPS printing, firewall, gparted
# DEBSWAY_DEFAULT: Y
# =======================================================
# Desktop Essentials — the "closest to Mint" completeness pass
# -------------------------------------------------------
# For a bare Sway desktop there's no Discover/systemsettings to surface
# things through, so this stays app-first: Flatpak + Flathub, printing
# (CUPS + drivers + network auto-discovery), and a firewall panel
# (gufw, the GTK frontend for ufw). Partition Manager on KDE becomes
# gparted here — already installed by 10-sway-core.sh.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [[ $EUID -eq 0 ]]; then
    log_err "Do not run this as root."
    exit 1
fi

log_head "Desktop Essentials"

log_info "Refreshing package lists..."
apt_update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Flatpak + Flathub — unified app source. (10-sway-core.sh also sets this
#    up; re-running here is a safe no-op for standalone runs.)
# ---------------------------------------------------------------------------
if ask "Set up Flatpak + Flathub?"; then
    install_pkgs "Flatpak" flatpak
    if command -v flatpak >/dev/null 2>&1; then
        if priv flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
            log_ok "Flathub remote added system-wide."
        else
            log_warn "Could not add the Flathub remote (may already exist)."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 2. Printing — CUPS + broad driver set + network printer auto-discovery
# ---------------------------------------------------------------------------
if ask "Install printing support (CUPS + drivers + network printer auto-discovery)?"; then
    install_pkgs "Printing" cups cups-browsed printer-driver-all

    if is_installed cups; then
        start_service cups
        log_ok "CUPS started."
    fi

    if getent group lpadmin >/dev/null 2>&1; then
        if id -nG "$ACTUAL_USER" 2>/dev/null | tr ' ' '\n' | grep -qx lpadmin; then
            log_ok "$ACTUAL_USER already in the lpadmin group."
        elif priv usermod -aG lpadmin "$ACTUAL_USER"; then
            log_ok "Added $ACTUAL_USER to lpadmin (manage printers without a password prompt each time)."
            log_warn "Log out and back in for this to take effect."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 3. Firewall panel. Installed by default; enabling is a separate, explicit
#    opt-in with an SSH-safe guard, since flipping on default-deny-incoming
#    blind could silently break something you rely on.
# ---------------------------------------------------------------------------
if ask "Install firewall control panel (gufw + ufw)?"; then
    install_pkgs "Firewall" gufw ufw

    if is_installed ufw && ask "Also enable it now (deny-incoming/allow-outgoing baseline, SSH-safe)?" "N"; then
        NEEDS_SSH_RULE=0
        if [ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]; then
            NEEDS_SSH_RULE=1
        elif command -v ss >/dev/null 2>&1 && ss -tln 2>/dev/null | grep -qE ':22\b'; then
            NEEDS_SSH_RULE=1
        fi
        if [ "$NEEDS_SSH_RULE" -eq 1 ]; then
            log_info "Active SSH session or listening sshd detected — allowing SSH before enabling default-deny."
            priv ufw allow ssh comment 'preserve SSH access before enabling default-deny' \
                || log_warn "Couldn't add the SSH allow-rule — double-check before enabling ufw if you're on SSH."
        fi
        priv ufw default deny incoming
        priv ufw default allow outgoing
        if priv ufw --force enable; then
            log_ok "ufw enabled: incoming denied by default, outgoing allowed. Manage exceptions via"
            log_ok "gufw (the GUI) or 'doas ufw allow <port>'."
        else
            log_warn "ufw failed to enable — check 'doas ufw status verbose'."
        fi
    else
        log_warn "Installed only — ufw is NOT enabled. Turn it on yourself via gufw"
        log_warn "(or 'doas ufw enable') once you've confirmed it won't block anything you rely on."
    fi
fi

# ---------------------------------------------------------------------------
# 4. gparted (GUI disk tool) — already part of 10-sway-core.sh; reinstall
#    here is a safe no-op on standalone runs. Kept for --only use.
# ---------------------------------------------------------------------------
if ask "Install gparted (disk/partition GUI)?"; then
    install_pkgs "gparted" gparted
fi

echo -e "${GREEN}Desktop essentials step complete.${NC}"