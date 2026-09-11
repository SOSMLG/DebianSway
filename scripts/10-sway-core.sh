#!/usr/bin/env bash
# DEBSWAY_DESC: Sway window-manager stack + greetd login + Flatpak + configs
# DEBSWAY_DEFAULT: Y
# =======================================================
# Sway Core — the window manager stack plus everything a
# bare Sway session needs to feel complete.
# -------------------------------------------------------
# Merges the "Sway Setup" and "GO ALL-IN (Barebone)" sections
# of the original debian_sway guide into one idempotent step:
#   * sway + status bar + launcher + lockscreen + idle
#   * Wayland utilities (grim/slurp/clipboard/screenshot)
#   * AMD GPU support (mesa vulkan — ThinkPad L14 G2 AMD)
#   * audio: PipeWire + WirePlumber
#   * greetd + tuigreet login manager (Wayland-native, TUI session picker)
#   * NetworkManager, printing, Flatpak + Flathub
#   * copies this repo's configs/ into ~/.config
#
# TLP / battery thresholds live in 33-useful-apps.sh, not here.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

if [ "$(id -u)" -eq 0 ]; then
    log_err "Do not run this as root."
    exit 1
fi

log_head "Sway Core"

log_info "Refreshing package lists..."
apt_update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Core sway + tools
# ---------------------------------------------------------------------------
install_pkgs "Sway core" \
    sway swaybg swaylock swayidle \
    waybar wlogout libwayland-dev grim slurp wl-clipboard \
    wofi alacritty mako-notifier libnotify-bin \
    brightnessctl pavucontrol blueman xdg-desktop-portal-wlr \
    mate-polkit clipman swayimg

# ---------------------------------------------------------------------------
# 2. Barebone/carry-on packages (VM-relevant & WM-essential)
# ---------------------------------------------------------------------------
# Devuan ships libpam-elogind instead of libpam-systemd
PAM_PROVIDER="libpam-systemd"
if [ -f /etc/devuan_version ]; then
    PAM_PROVIDER="libpam-elogind"
fi

install_pkgs "Wayland/core libs" \
    wayland-protocols xwayland libinput-tools "$PAM_PROVIDER" \
    xserver-xorg-core mesa-utils gvfs xdg-utils gnome-calendar htop nautilus

# AMD GPU multilib — Vega iGPU on the L14 G2 AMD. amdgpu is in-kernel;
# this gives us Vulkan + media acceleration.
install_pkgs "AMD Vulkan drivers" mesa-vulkan-drivers

# ---------------------------------------------------------------------------
# 3. Audio — PipeWire + WirePlumber (Wayland-native, Bluetooth-capable)
# ---------------------------------------------------------------------------
install_pkgs "Audio (PipeWire)" pipewire pipewire-audio wireplumber

# ---------------------------------------------------------------------------
# 4. NetworkManager (apps + CLI). The GNOME applet gives a tray
#    + password prompts on the wlan menus.
# ---------------------------------------------------------------------------
install_pkgs "NetworkManager" network-manager network-manager-gnome
start_service NetworkManager

# ---------------------------------------------------------------------------
# 5. greetd + tuigreet — minimal Wayland login manager
# ---------------------------------------------------------------------------
# Create the D-Bus session wrapper so sway gets DBUS_SESSION_BUS_ADDRESS.
# Without this, mako, waybar, xdg-desktop-portal-wlr, playerctl etc. fail.
if [ ! -x /usr/local/bin/sway-session ]; then
    priv tee /usr/local/bin/sway-session > /dev/null << 'WRAPPER'
#!/bin/sh
exec dbus-run-session -- sway
WRAPPER
    priv chmod +x /usr/local/bin/sway-session
    log_ok "Created /usr/local/bin/sway-session (D-Bus session wrapper)"
fi
# Greeter session entry so the "DebSway" picker choice (not raw sway)
# always launches inside a D-Bus session. Without the bus, mako,
# portals, and debsway notify() silently do nothing. A distro upgrade
# may overwrite sway.desktop, but this file is ours and survives.
priv tee /usr/share/wayland-sessions/debsway-sway.desktop > /dev/null << 'DESKTOP'
[Desktop Entry]
Name=DebSway (Sway + session bus)
Comment=Sway via dbus-run-session so notifications and portals work
Exec=/usr/local/bin/sway-session
Type=Application
DesktopNames=sway
DESKTOP
log_ok "Installed DebSway greeter session (pick it instead of raw Sway)."
# opendoas — the privilege escalator for this toolkit (BSD-minimal `doas`;
# every script reaches root through the priv() helper in lib/common.sh,
# which prefers doas and falls back to sudo). Installed here, first, so
# all later steps can rely on it. sudo stays installed as a fallback.
if ! is_installed opendoas; then
    install_pkgs "opendoas (doas privilege escalation)" opendoas
fi
# tuigreet is the greeter: a TUI purpose-built for greetd session picking
# (far less fragile than wlgreet's GTK layer-shell). wlgreet stays installed
# as a fallback greeter.
if ! is_installed greetd || ! is_installed tuigreet; then
    install_pkgs "greetd login manager" greetd tuigreet
fi

# greetd runs its greeter as a dedicated unprivileged user. Debian's
# package doesn't create one, so make sure "greeter" exists + can render.
if ! id -u greeter >/dev/null 2>&1; then
    priv adduser --disabled-password --gecos "greetd greeter" greeter
    priv usermod -aG video,render,input greeter
fi

priv mkdir -p /etc/greetd
if [ -f /etc/greetd/config.toml ]; then
    priv cp /etc/greetd/config.toml "/etc/greetd/config.toml.bak.$(date +%Y%m%d_%H%M%S)"
    log_info "Existing /etc/greetd/config.toml backed up."
fi
priv tee /etc/greetd/config.toml > /dev/null << 'EOF'
[terminal]
vt = 2

# tuigreet renders the login screen (user picker + password + session menu),
# then launches the selected session as the logged-in user. --cmd is the
# default (pre-selected) session; the full list comes from
# /usr/share/wayland-sessions (pick "DebSway" there, not raw Sway, so the
# session gets a D-Bus bus for mako/portals/notify).
# To auto-boot straight into a session instead, use an [initial_session]
# block (example below) rather than removing the picker.
[default_session]
command = "tuigreet --time --remember --remember-session -d --cmd /usr/local/bin/sway-session"
user = "greeter"

# Optional auto-login block — uncomment to skip the picker for that user:
# [initial_session]
# command = "/usr/local/bin/sway-session"
# user = "your-username"
EOF
log_ok "greetd configured to boot into the tuigreet login screen."
start_service greetd
log_ok "greetd enabled — your next login goes through the tuigreet picker."

# Seat management belongs to elogind on this stack (sway speaks the logind
# API); a stray seatd only competes for the same devices. Park it wherever
# it is enabled (both init systems — package stays, re-enable any time).
if command_exists update-rc.d || [ -x /usr/sbin/update-rc.d ]; then
    priv /usr/sbin/update-rc.d seatd disable >/dev/null 2>&1 || true
fi
if command_exists rc-update || [ -x /usr/sbin/rc-update ]; then
    priv /usr/sbin/rc-update del seatd default >/dev/null 2>&1 || true
fi
priv service seatd stop >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 5b. Give greetd sole ownership of the boot console
# ---------------------------------------------------------------------------
# Exactly one display manager may auto-start: SDDM stays *installed* as a
# manual fallback, but its runlevel links are removed so it no longer races
# greetd (both enabled = neither owns the VT reliably).
for _rl in 2 3 4 5; do
    priv rm -f "/etc/rc${_rl}.d"/S??sddm 2>/dev/null || true
done
log_ok "SDDM demoted to manual fallback (still installed; re-enable with S-links if ever needed)."

# getty on the greeter's VT fights it (a respawning getty steals the console
# back and forth). The greeter takes vt=2 (reachable via Ctrl+Alt+F2), so:
# tty1's getty is restored for boot messages/console login, tty2's is parked,
# and tty3-6 gettys stay untouched. Reload init without rebooting.
if grep -qE '^#(1:.*tty1)  # debsway:' /etc/inittab 2>/dev/null; then
    priv sed -i -E 's/^#(1:.*tty1)  # debsway:.*/\1/' /etc/inittab
    log_ok "getty restored on tty1."
fi
if grep -qE '^2:.*getty.*tty2' /etc/inittab 2>/dev/null; then
    priv cp /etc/inittab "/etc/inittab.bak.$(date +%Y%m%d_%H%M%S)"
    priv sed -i -E 's/^(2:.*getty.*tty2)/#\1  # debsway: greetd owns tty2/' /etc/inittab
    priv init q 2>/dev/null || true
    log_ok "getty moved off tty2 (backup: /etc/inittab.bak.*)."
else
    log_ok "tty2 already free of getty — greetd owns the console."
fi

# ---------------------------------------------------------------------------
# 6. Flatpak + Flathub (used by some optional scripts; browser stays native)
# ---------------------------------------------------------------------------
if ask "Set up Flatpak + Flathub?"; then
    install_pkgs "Flatpak" flatpak
    if command -v flatpak >/dev/null 2>&1; then
        if priv flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
            log_ok "Flathub remote added system-wide."
        else
            log_warn "Could not add the Flathub remote (may already exist)."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 7. Bake configs into ~/.config (catppuccinThemed, from 22-theme-default.sh)
# ---------------------------------------------------------------------------
CONFIGS_SRC="$SCRIPT_DIR/../configs"
if [ -d "$CONFIGS_SRC" ]; then
    log_info "Copying configs/ into ~/.config/ ..."
    for d in sway waybar wofi alacritty mako swayosd wlogout kanshi gammastep environment.d fastfetch; do
        if [ -d "$CONFIGS_SRC/$d" ]; then
            mkdir -p "$HOME/.config/$d"
            if cp -r "$CONFIGS_SRC/$d/." "$HOME/.config/$d/"; then
                log_ok "  ~/.config/$d"
            else
                log_warn "  failed to copy $d"
            fi
        fi
    done
    log_info "Wallpapers copied — you can swap ~/.config/sway/wallpapers/ freely."
    log_info "Run scripts/21-debsway-cli.sh to install the debsway theme CLI."
else
    log_warn "configs/ not found next to scripts/ — skipping (run 22-theme-default.sh instead)."
fi

# ---------------------------------------------------------------------------
# 8. Powder/safety: firmware for the Wi-Fi module lives on the L14 as
#    Intel AX200 / Realtek RTL8852BE / MediaTek MT7921 — the broad firmware
#    set in 13-hardware.sh covers them all. Run it next.
# ---------------------------------------------------------------------------
log_ok "Sway core installed."
log_warn "Next: scripts/11-backports.sh (repos) + scripts/13-hardware.sh (firmware)."
log_warn "Reboot recommended after the whole run so greetd takes over the login."