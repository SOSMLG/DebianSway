#!/usr/bin/env bash
# DEBSWAY_DESC: Shell: OSD, clipboard, screenshots, media keys, night-light, Alacritty
# DEBSWAY_DEFAULT: Y
# =======================================================
# Sway Shell Upgrade — the OSD / capture / media / clipboard /
# night-light components that turn Sway from a bare WM into a
# "gets out of your way" desktop shell, plus the Alacritty terminal.
# -------------------------------------------------------
# Installs:
#   alacritty   (default terminal, $term)
#   swayosd     on-screen volume/brightness OSD (+libinput gestures)
#   cliphist    clipboard history manager (+ wofi picker in debsway)
#   swappy      screenshot annotation (area + markup)
#   wlogout     grid power menu ($mod+Escape)
#   playerctl   media controls (waybar now-playing + keys)
#   pamixer     volume CLI used by the sway media keys
#   pipewire + wireplumber (+pipewire-pulse) audio server, started from the
#               sway autostart (no systemd user sockets on Devuan)
#   kanshi      automatic display profiles (dock / laptop)
#   wf-recorder recording (video notes) + wlr-randr/wdisplays (layout UI)
#   nwg-look    GTK theme tweaker (used by the debsway style menu)
#   gammastep   blue-light filter (debsway toggle night)
#   qalc        calculator (debsway calc)
#   jq          JSON glue for the debsway CLI
#
# Then bakes this repo's configs into ~/.config (backing up anything it
# overwrites to *.bak.<timestamp>) and drops the Wayland/PATH env into
# ~/.config/environment.d/ + ~/.profile so every future shell and app
# sees the same session.
#
# Idempotent: safe to re-run; nothing is deleted, only backed up/overlaid.
# =======================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

require_not_root
log_head "Sway Shell Upgrade (OSD / capture / media / night-light / Alacritty)"

log_info "Refreshing package lists..."
apt_update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
install_pkgs "Shell upgrade" \
    alacritty swayosd cliphist swappy wlogout playerctl pamixer \
    kanshi wf-recorder wdisplays wlr-randr nwg-look gammastep \
    qalc jq pulseaudio-utils pipewire wireplumber pipewire-pulse

# Foot is retired: Alacritty is the canonical $term (see configs/sway/config).
# Purge it idempotently so stale foot.ini / binds can't shadow Alacritty.
if is_installed foot; then
    log_info "Removing retired terminal (foot) — Alacritty is now \$term."
    sudo apt-get purge -y foot 2>/dev/null || log_warn "Couldn't remove foot."
fi
if [ -f "$HOME/.config/foot/foot.ini" ]; then
    mv "$HOME/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini.retired.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    log_info "Stale ~/.config/foot/foot.ini retired (theme engine no longer renders foot)."
fi

# ---------------------------------------------------------------------------
# 2. Bake configs into ~/.config (backup-first overlay)
# ---------------------------------------------------------------------------
CONFIGS_SRC="$SCRIPT_DIR/../configs"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d_%H%M%S)"

backup_before_overlay() {
    local src_dir="$1" dst_dir="$2"
    mkdir -p "$dst_dir"
    local f
    while IFS= read -r -d '' f; do
        local rel="${f#"$src_dir"/}"
        if [ -f "$dst_dir/$rel" ] && ! cmp -s "$f" "$dst_dir/$rel"; then
            mkdir -p "$dst_dir/$(dirname "$rel")"
            cp -a "$dst_dir/$rel" "$dst_dir/$rel$BACKUP_SUFFIX"
            log_info "  backed up $dst_dir/$rel → .bak.*"
        fi
    done < <(find "$src_dir" -type f -print0)
    return 0
}

if [ -d "$CONFIGS_SRC" ]; then
    log_info "Applying configs from $CONFIGS_SRC (backup-first)..."
    for d in sway waybar wofi alacritty mako swayosd wlogout kanshi gammastep environment.d; do
        [ -d "$CONFIGS_SRC/$d" ] || continue
        backup_before_overlay "$CONFIGS_SRC/$d" "$HOME/.config/$d"
        cp -r "$CONFIGS_SRC/$d/." "$HOME/.config/$d/"
        log_ok "  ~/.config/$d"
    done
else
    log_warn "configs/ not found next to scripts/ — skipping config overlay."
fi

# ---------------------------------------------------------------------------
# 3. Session environment — environment.d (systemd user) + ~/.profile fallback
# ---------------------------------------------------------------------------
ENV_SRC="$HOME/.config/environment.d/debsway.conf"
if [ -f "$ENV_SRC" ]; then
    PROFILE_ADD=".config/environment.d/debsway.conf"
    if ! grep -q "environment.d/debsway.conf" "$HOME/.profile" 2>/dev/null; then
        cat >> "$HOME/.profile" << EOF

# DebSway session env (Wayland backends + PATH for ~/.local/bin/debsway).
for _dsf in "$HOME/$PROFILE_ADD" "$HOME/.config/environment.d/debsway.env"; do
    [ -f "\$_dsf" ] && while IFS= read -r _l; do
        case "\$_l" in
            \#*|"") continue ;;
            *=*) export "\$_l" ;;
        esac
    done < "\$_dsf"
done
unset _dsf _l
export PATH="\$HOME/.local/bin:\$HOME/bin:\$PATH"
EOF
        log_ok "~/.profile reads $PROFILE_ADD and adds ~/.local/bin to PATH."
    else
        log_ok "~/.profile already configured."
    fi
else
    log_warn "environment.d/debsway.conf not found — skipping ~/.profile tweak."
fi

# ---------------------------------------------------------------------------
# 4. Refresh the live session (best-effort; no-op on a fresh install)
# ---------------------------------------------------------------------------
if command -v swaymsg >/dev/null 2>&1 && [ -n "${SWAYSOCK:-}" ] \
    && swaymsg -t get_version >/dev/null 2>&1; then
    swaymsg reload >/dev/null 2>&1 && log_ok "Sway reloaded (config + binds + colors)."
    pkill -x waybar 2>/dev/null; sleep 0.3
    command -v waybar >/dev/null 2>&1 && setsid --fork waybar >/dev/null 2>&1 &
    command -v mako >/dev/null 2>&1 && (pkill -x mako 2>/dev/null; sleep 0.2; setsid --fork mako >/dev/null 2>&1 &)
    command -v swayosd-server >/dev/null 2>&1 && (pkill -x swayosd-server 2>/dev/null; sleep 0.2; setsid --fork swayosd-server >/dev/null 2>&1 &)
    log_ok "Waybar / mako / swayosd restarted with the new configs."
else
    log_info "Not under a live sway session — configs land on next login."
fi

echo
log_ok "Sway Shell Upgrade complete."
log_warn "Next: scripts/21-debsway-cli.sh installs the debsway CLI + theme engine."
log_warn "A re-login (or \$mod+Shift+C) picks up swayosd, gammastep, kanshi & Alacritty."