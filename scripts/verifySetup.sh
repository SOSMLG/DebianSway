#!/usr/bin/env bash
# =======================================================
# Verify Setup — end-state audit
# -------------------------------------------------------
# One-pass check of the toolkit's expected end state:
# group membership, key packages, fonts, Firefox user.js,
# catppuccin config markers, and enabled services.
# Designed to be run from run.sh --verify after a run, or
# standalone at any time.
#
# Prints PASS/FAIL/WARN lines and exits non-zero if any
# critical check failed, so it can gate CI/validation.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

PASS=0; FAIL=0; WARN=0

report() {  # report <name> <status> <detail>
    case "$2" in
        ok)
            printf '  PASS  %-48s %s\n' "$1" "${3:-}"
            PASS=$((PASS + 1))
            ;;
        fail)
            printf '  FAIL  %-48s %s\n' "$1" "${3:-}"
            FAIL=$((FAIL + 1))
            ;;
        warn)
            printf '  WARN  %-48s %s\n' "$1" "${3:-}"
            WARN=$((WARN + 1))
            ;;
    esac
}

pkg() {  # pkg <name> [critical|optional]
    local name="$1" level="${2:-critical}"
    local state detail
    if is_installed "$name"; then
        state="ok"; detail="installed"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="not installed (optional — OK to skip)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "$name" "$state" "$detail"
}

bin() {  # bin <command> [critical|optional]
    local name="$1" level="${2:-critical}"
    local state detail
    if command -v "$name" >/dev/null 2>&1; then
        state="ok"; detail="$(command -v "$name")"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="not installed (optional — OK to skip)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "bin: $name" "$state" "$detail"
}

cfg() {  # cfg <label> <path> [critical|optional]
    local label="$1" path="$2" level="${3:-critical}"
    local state detail
    if [ -f "$path" ]; then
        state="ok"; detail="present"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="missing (optional — OK to skip)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "cfg: $label" "$state" "$detail"
}

# pkg_glob: package names that shifted (e.g. libavcodec-extra* across releases)
pkg_glob() {
    local name="$1" level="${2:-critical}"
    local state detail
    if dpkg-query -W -f='${Status}' "$name" 2>/dev/null | grep -q "install ok installed" \
    || [ -n "$(dpkg-query -l "${name}*" 2>/dev/null | grep '^ii')" ]; then
        state="ok"; detail="installed"
    elif [ "$level" = "optional" ]; then
        state="warn"; detail="not installed (optional — OK to skip)"
    else
        state="fail"; detail="missing — re-run the relevant script"
    fi
    report "$name*" "$state" "$detail"
}

# service_state: enabled under systemd OR OpenRC; running via process name.
service_state() {
    local svc="$1" procname="$2" level="${3:-fail}"
    local enabled="" running=""
    if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
        if systemctl is-enabled "$svc" >/dev/null 2>&1 || systemctl is-enabled "${svc}.service" >/dev/null 2>&1; then
            enabled="systemd"
        fi
    elif command -v rc-update >/dev/null 2>&1; then
        if rc-update show 2>/dev/null | awk -v s="$svc" '$1==s{found=1} END{exit !found}'; then
            enabled="openrc"
        fi
    fi
    pgrep -x "$procname" >/dev/null 2>&1 && running="yes"

    if [ -n "$running" ]; then
        report "$svc (service)" ok "${enabled:-running, not enabled}"
    elif [ "$level" = "optional" ]; then
        report "$svc (service)" warn "not running"
    else
        report "$svc (service)" fail "not running"
    fi
}

log_head "Setup verification"

echo -e "  (user: ${CYAN}${ACTUAL_USER}${NC})\n"

# --- 1. Group membership ------------------------------------------------
for g in input video render plugdev lpadmin; do
    if id -nG "$ACTUAL_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$g"; then
        report "group: $g" ok
    else
        report "group: $g" warn "user not in $g (lpadmin optional — re-run 30-desktop-essentials or: doas usermod -aG $g $ACTUAL_USER)"
    fi
done

# --- 2. Package baseline (default-Y/lean set) ----------------------------
pkg sway
pkg swaybg
pkg swaylock
pkg swayidle
pkg waybar
pkg fuzzel
pkg foot
pkg mako-notifier
pkg libnotify-bin
pkg swayosd
pkg cliphist
pkg swappy
pkg wlogout
pkg playerctl
pkg pamixer
pkg kanshi
pkg wf-recorder
pkg wdisplays
pkg wlr-randr
pkg nwg-look
pkg gammastep
pkg qalc optional
pkg jq
pkg opendoas
pkg greetd
pkg tuigreet
pkg wlgreet optional
pkg blueman
pkg thunar
pkg thunar-volman
pkg tumbler
pkg gvfs-backends
pkg udisks2
pkg mpv
pkg vlc optional
pkg zathura
pkg yazi
pkg pass optional
pkg btop
pkg eza
pkg bat
pkg zoxide
pkg tlp
pkg firmware-iwlwifi optional
pkg ffmpeg
pkg_glob libavcodec-extra
pkg firefox-esr
pkg fonts-noto-color-emoji
pkg fonts-noto-core optional
pkg fastfetch
pkg flatpak
pkg timeshift
pkg bluez
pkg bluetooth
pkg fwupd optional
pkg chrony optional
pkg mesa-vulkan-drivers optional

# --- 3. Optional/user-picked packages (warn roll, not fail) --------------
pkg codium optional
pkg opencode optional
pkg heroic optional
pkg steam optional
pkg gimp optional
pkg keepassxc optional
# 41-dev-essentials.sh — C/C++ + Python toolchains (editor-free, optional)
bin gcc optional
bin g++ optional
bin gdb optional
bin clangd optional
bin cmake optional
pkg python3-numpy optional
pkg python3-matplotlib optional
pkg python3-scipy optional
pkg python3-pandas optional
pkg python3-pytest optional
bin nvim optional
# 46-neovim.sh blesses Debian 0.10 + a v14-pinned LazyVim config; anything
# newer rides the current LazyVim line unpinned.
if command -v nvim >/dev/null 2>&1; then
    _nver="$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    if [ -n "$_nver" ] && printf '%s\n' "0.11.2" "$_nver" | sort -V -C 2>/dev/null; then
        report "nvim LazyVim-ready" ok "$_nver (>= 0.11.2, current line)"
    elif [ -n "$_nver" ] && printf '%s\n' "0.9.0" "$_nver" | sort -V -C 2>/dev/null \
        && grep -rq 'version = "14\.\*"' "$HOME/.config/nvim/lua/plugins/" 2>/dev/null; then
        report "nvim LazyVim-ready" ok "$_nver (v14 pinned for 0.10)"
    else
        report "nvim LazyVim-ready" warn "${_nver:-unknown} — re-run 46-neovim.sh"
    fi
fi

# --- 4. Fonts -------------------------------------------------------------
# NOTE: string-test, not `| grep -q` — with `set -o pipefail`, grep -q
# exits on first match while fc-list (~3000 lines) is still writing, so
# fc-list dies of SIGPIPE (141) and the pipeline spuriously FAILs.
if [ -n "$(fc-list 2>/dev/null | grep -i "JetBrainsMono Nerd Font")" ]; then
    report "JetBrainsMono Nerd Font" ok
else
    report "JetBrainsMono Nerd Font" fail "not found — re-run 17-fonts.sh"
fi

# --- 5. Firefox hardening -------------------------------------------------
if grep -rlsq "user_pref" "$HOME/.mozilla/firefox" 2>/dev/null; then
    report "Firefox hardened user.js" ok
else
    report "Firefox hardened user.js" warn "no user.js found (harden Firefox or skip)"
fi

# --- 6. DebSway theme / CLI ------------------------------------------------
bin debsway
if [ -x "$HOME/.local/share/debsway/bin/debsway" ]; then
    report "debsway install tree" ok
else
    report "debsway install tree" fail "missing — re-run 21-debsway-cli.sh"
fi
if [ -f "$HOME/.local/state/debsway/theme" ]; then
    report "debsway active theme" ok "$(cat "$HOME/.local/state/debsway/theme")"
else
    report "debsway active theme" fail "no marker — re-run 21-debsway-cli.sh (debsway theme set)"
fi
if [ -f "$HOME/.config/sway/colors.conf" ] && grep -q '^set \$bg' "$HOME/.config/sway/colors.conf"; then
    report "sway palette (colors.conf)" ok
else
    report "sway palette (colors.conf)" fail "missing — re-run 20-shell-upgrade.sh"
fi
cfg "sway/config" "$HOME/.config/sway/config"
cfg "waybar/config" "$HOME/.config/waybar/config"
cfg "fuzzel/fuzzel.ini" "$HOME/.config/fuzzel/fuzzel.ini"
cfg "foot/foot.ini" "$HOME/.config/foot/foot.ini"
cfg "mpv/mpv.conf" "$HOME/.config/mpv/mpv.conf" optional
cfg "swayosd/style.css" "$HOME/.config/swayosd/style.css"
cfg "wlogout/style.css" "$HOME/.config/wlogout/style.css"
cfg "wlogout/layout" "$HOME/.config/wlogout/layout"
cfg "kanshi/config" "$HOME/.config/kanshi/config"
cfg "gammastep/config.ini" "$HOME/.config/gammastep/config.ini"
cfg "waybar/style.css" "$HOME/.config/waybar/style.css"

# --- 7. Catppuccin wallpaper -------------------------------------------------
if [ -f "$HOME/.config/sway/wallpapers/catppuccin-mocha.png" ]; then
    report "Catppuccin wallpaper" ok
else
    report "Catppuccin wallpaper" warn "wallpaper missing — re-run 22-theme-default.sh"
fi

# --- 8. Services -----------------------------------------------------------
service_state bluetooth bluetoothd optional
service_state tlp tlp optional
service_state cups cupsd optional
service_state chrony chronyd optional
service_state greetd greetd critical
service_state NetworkManager NetworkManager optional

echo
echo -e "${GREEN}  ${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${WARN} warnings${NC}"
if [ "$FAIL" -gt 0 ]; then
    echo
    log_err "Some checks failed — see lines above, then re-run the relevant script."
    exit 1
fi
exit 0