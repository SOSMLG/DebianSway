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
#   * greetd + wlgreet login manager (Wayland-native)
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
# 5. greetd + wlgreet — minimal Wayland login manager
# ---------------------------------------------------------------------------
# Create the D-Bus session wrapper so sway gets DBUS_SESSION_BUS_ADDRESS.
# Without this, mako, waybar, xdg-desktop-portal-wlr, playerctl etc. fail.
if [ ! -x /usr/local/bin/sway-session ]; then
    sudo tee /usr/local/bin/sway-session > /dev/null << 'WRAPPER'
#!/bin/sh
exec dbus-run-session -- sway
WRAPPER
    sudo chmod +x /usr/local/bin/sway-session
    log_ok "Created /usr/local/bin/sway-session (D-Bus session wrapper)"
fi
# Greeter session entry so the "DebSway" picker choice (not raw sway)
# always launches inside a D-Bus session. Without the bus, mako,
# portals, and debsway notify() silently do nothing. A distro upgrade
# may overwrite sway.desktop, but this file is ours and survives.
sudo tee /usr/share/wayland-sessions/debsway-sway.desktop > /dev/null << 'DESKTOP'
[Desktop Entry]
Name=DebSway (Sway + session bus)
Comment=Sway via dbus-run-session so notifications and portals work
Exec=/usr/local/bin/sway-session
Type=Application
DesktopNames=sway
DESKTOP
log_ok "Installed DebSway greeter session (pick it instead of raw Sway)."
if ! is_installed greetd || ! is_installed wlgreet; then
    install_pkgs "greetd login manager" greetd wlgreet
fi

# greetd runs its greeter as a dedicated unprivileged user. Debian's
# package doesn't create one, so make sure "greeter" exists + can render.
if ! id -u greeter >/dev/null 2>&1; then
    sudo adduser --disabled-password --gecos "greetd greeter" greeter
    sudo usermod -aG video,render,input greeter
fi

sudo mkdir -p /etc/greetd
if [ -f /etc/greetd/config.toml ]; then
    sudo cp /etc/greetd/config.toml "/etc/greetd/config.toml.bak.$(date +%Y%m%d_%H%M%S)"
    log_info "Existing /etc/greetd/config.toml backed up."
fi
sudo tee /etc/greetd/config.toml > /dev/null << 'EOF'
[terminal]
vt = 1

# wlgreet renders the login screen (user picker + password), then launches
# the selected command as the logged-in user. Remove "wlgreet --command"
# to auto-boot straight into the command instead.
[default_session]
command = "wlgreet --command /usr/local/bin/sway-session"
user = "greeter"

# Optional auto-login block — uncomment to skip the picker for that user:
# [initial_session]
# command = "sway"
# user = "your-username"
EOF
log_ok "greetd configured to boot into the wlgreet login screen."
start_service greetd
log_ok "greetd enabled — your next login goes through the wlgreet picker."

# ---------------------------------------------------------------------------
# 6. Flatpak + Flathub (used by some optional scripts; browser stays native)
# ---------------------------------------------------------------------------
if ask "Set up Flatpak + Flathub?"; then
    install_pkgs "Flatpak" flatpak
    if command -v flatpak >/dev/null 2>&1; then
        if sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
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