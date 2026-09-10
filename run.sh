#!/usr/bin/env bash
# ==========================================
# deb-sway-thinkpad — Debian 13 (Trixie) + Sway — Ordered Runner
# Runs setup scripts in the order defined below,
# asks Y/N per script with a default value.
# For a fully unattended run:  ./install.sh
# This runner is for when you want to pick-and-choose.
# ==========================================

set -uo pipefail
# NOTE: intentionally not using `set -e` here. Individual scripts manage
# their own error handling; one script failing should not silently abort
# every later step. Each script is still expected to exit non-zero on
# failure so this runner can report it.

# --- Colors ---
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[0;36m"
RESET="\033[0m"

# --- Directory setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

usage() {
    cat <<EOF
Usage: $0 [options]

Runs the toolkit's setup scripts in the order defined below, asking Y/N
per script. Options:

  --list                Print each script (order, description, default) and exit.
  --only a.sh,b.sh      Run only the listed scripts, in their defined order.
                        Accepts filenames with or without the '.sh' suffix.
  --yes, -y             Answer every prompt with its default (unattended).
  --full                Like --yes + treat every script's default as Y
                        (all optional groups included). Used by install.sh.
  --no-update           Skip the runner's single 'apt-get update'.
  --verify              After the run, run scripts/verifySetup.sh and report results.
  -h, --help            Show this help.

TL;DR:  ./install.sh         one-command, everything, unattended
        ./run.sh --list      see what it would do
        ./run.sh --only 01-backports.sh,usefulApps.sh
EOF
}

# --- Flags -----------------------------------------------------------------
DO_LIST=0
DO_VERIFY=0
ASSUME_YES=0
FULL=0
SKIP_APT_UPDATE=0
ONLY_NAMES=()

while [ $# -gt 0 ]; do
    case "$1" in
        --list) DO_LIST=1 ;;
        --only)
            [ $# -ge 2 ] || { echo -e "${RED}--only needs a comma-separated list of scripts.${RESET}"; exit 1; }
            shift
            IFS=',' read -ra _entries <<< "$1"
            ONLY_NAMES+=("${_entries[@]}")
            ;;
        --yes|-y) ASSUME_YES=1 ;;
        --full) ASSUME_YES=1; FULL=1 ;;
        --no-update|--skip-apt-update) SKIP_APT_UPDATE=1 ;;
        --verify) DO_VERIFY=1 ;;
        -h|--help) usage; exit 0 ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}"
            usage
            exit 1
            ;;
    esac
    shift
done

[ "$ASSUME_YES" -eq 1 ] && export DEBSWAY_ASSUME_YES=1
[ "$FULL" -eq 1 ] && export DEBSWAY_FULL=1

# --- Refuse to run as root directly ---
# Per-user state (Firefox profile, ~/.bashrc, sway configs, ~/.local/bin)
# must land in the real user's $HOME, not /root. Scripts call sudo
# themselves for the bits that need it.
if [ "$(id -u)" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    echo -e "${RED}Please run this as your normal user, not as root / sudo bash run.sh.${RESET}"
    echo -e "${YELLOW}Each script will call sudo itself for the parts that need it.${RESET}"
    exit 1
fi

# --- Distro check (Debian/Devuan; both ship /etc/debian_version) ---
if [ -f /etc/debian_version ]; then
    echo -e "${GREEN}Debian-based system detected: $(cat /etc/debian_version)${RESET}"
    if [ -f /etc/devuan_version ]; then
        echo -e "${YELLOW}Devuan detected: $(cat /etc/devuan_version) — the sway/systemd parts may need manual tweaks.${RESET}"
    fi
else
    echo -e "${YELLOW}Warning: this toolkit targets Debian. Your system may not be compatible.${RESET}"
    if [ -z "${DEBSWAY_ASSUME_YES:-}" ]; then
        read -r -p "Continue anyway? (y/N): " continue_anyway
        [[ "$continue_anyway" =~ ^[Yy]$ ]] || exit 1
    fi
fi

# --- Ordered list: "script|description|default" ---
# Defaults: Y = core setup, N = optional group / maintenance utility.
# --full (install.sh) forces every default to Y.
SCRIPTS=(
    "00-sway-core.sh|Install the Sway window-manager stack (+ greetd login, Flatpak, configs)|Y"
    "01-backports.sh|Enable Debian backports (trixie-backports) + apt pinning|Y"
    "addUserToGroups.sh|Add your user to input/video/render groups|Y"
    "hardwareSupport.sh|Install WiFi/Bluetooth/AMD GPU firmware, microcode + fwupd|Y"
    "bluetoothSetup.sh|Set up Bluetooth stack, Blueman applet + A2DP audio|Y"
    "multimediaCodecs.sh|Install audio/video codecs + DVD playback|Y"
    "firefoxHarden.sh|Install & harden Firefox ESR (Betterfox + privacy policies)|Y"
    "installFonts.sh|Install Noto, Font Awesome + JetBrainsMono Nerd Font|Y"
    "terminalButterbash.sh|Install ButterBash (saner shell + aliases)|Y"
    "fastfetchConfig.sh|Install fastfetch + curated config presets|Y"
    "catppuccinSway.sh|Catppuccin Mocha/Red default theme + cursor pack (legacy alias of \`debsway theme set\`)|Y"
    "desktopEssentials.sh|Flatpak/Flathub, printing (CUPS), firewall (gufw/ufw), gparted|Y"
    "timeshiftSetup.sh|Install Timeshift for system snapshots/restore|Y"
    "networkTimeSync.sh|Enable NTP time sync via chrony (harmless if already synced)|N"
    "usefulApps.sh|Install VLC, TLP (+ 80% battery cap), archive + thumbnail support|Y"
    "aiOpencode.sh|Install OpenCode AI coding agent + Super+A hotkey + system skill file|Y"
    "25-swayShellUpgrade.sh|Sway shell: OSD, clipboard history, screenshots, media keys, night-light + Foot terminal|Y"
    "26-debswayCli.sh|Install the debsway CLI + theme engine (debsway menu/theme/doctor...)|Y"
    "installVscodium.sh|(optional) Install VSCodium editor|N"
    "vscodiumDevSetup.sh|(optional) Configure VSCodium for C++/Python development|N"
    "devToolsExtras.sh|(optional) Dev extras: btop, eza, bat, zoxide, Neovim+lazy.nvim, KeePassXC|N"
    "installPhotogimp.sh|(optional) Install GIMP + PhotoGIMP Photoshop-like layout|N"
    "gamingSetup.sh|(optional) Install Heroic / Steam / Wine + game libraries|N"
    "vesktopTelegram.sh|(optional) Install Vesktop (Discord) / Telegram|N"
    "systemMaintenance.sh|(utility) apt cleanup + dead symlink tidy|N"
    "configBackup.sh|(utility) Back up your $HOME config into a timestamped archive|N"
    "exportToSkel.sh|(utility) Copy per-user defaults into /etc/skel for new accounts|N"
)

# --- --list: print the ordering and exit ----------------------------------
if [ "$DO_LIST" -eq 1 ]; then
    echo -e "${BLUE}Toolkit scripts, in run order:${RESET}\n"
    i=1
    for ENTRY in "${SCRIPTS[@]}"; do
        SCRIPT="${ENTRY%%|*}"
        REST="${ENTRY#*|}"
        DESC="${REST%%|*}"
        DEFAULT="${REST##*|}"
        printf '  %2d.  %-28s default: %-1s  %s\n' "$i" "$SCRIPT" "${DEFAULT^^}" "$DESC"
        ((i++))
    done
    echo
    echo -e "Run everything unattended: ${CYAN}./install.sh${RESET}"
    echo -e "Run everything interactively: ${CYAN}./run.sh${RESET}"
    exit 0
fi

# --- --only: pick the subset, keep the defined order -----------------------
SELECTED=()
if [ "${#ONLY_NAMES[@]}" -gt 0 ]; then
    declare -A WANTED
    for n in "${ONLY_NAMES[@]}"; do
        [ -z "$n" ] && continue
        n="${n%.sh}"
        WANTED["${n%%.sh}"]=1
    done
    unset n
    for ENTRY in "${SCRIPTS[@]}"; do
        SCRIPT="${ENTRY%%|*}"
        if [ -n "${WANTED[${SCRIPT%.sh}]+x}" ]; then
            SELECTED+=("$ENTRY")
            unset "WANTED[${SCRIPT%.sh}]"
        fi
    done
    for leftover in "${!WANTED[@]}"; do
        echo -e "${YELLOW}⚠ Not a toolkit script, ignoring: $leftover.sh${RESET}"
    done
    unset leftover
    if [ "${#SELECTED[@]}" -eq 0 ]; then
        echo -e "${RED}No matching scripts for --only. Use --list to see available ones.${RESET}"
        exit 1
    fi
else
    SELECTED=("${SCRIPTS[@]}")
fi

echo -e "${BLUE}=========================================================${RESET}"
echo -e "${BLUE}   deb-sway-thinkpad — Debian 13 (Trixie) + Sway${RESET}"
echo -e "${BLUE}=========================================================${RESET}\n"

# --- One apt refresh, then let the scripts skip their own ------------------
export DEBSWAY_SKIP_APT_UPDATE=1
if [ "$SKIP_APT_UPDATE" -eq 0 ]; then
    echo -e "${CYAN}[*] Refreshing package lists once (scripts skip their own refreshes)...${RESET}"
    if ! sudo apt-get update; then
        echo -e "${YELLOW}[!] apt-get update failed — continuing anyway. Some installs may fail if lists are stale.${RESET}"
    fi
fi

# --- Summary log -----------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/deb-sway-thinkpad"
mkdir -p "$STATE_DIR"
LOG_FILE="$STATE_DIR/last-run.log"
record_run() { printf '%(%F %T)T  %s\n' -1 "$1" >> "$LOG_FILE"; }

record_run "$0 ${ONLY_NAMES[*]:-all} (assume-yes=${ASSUME_YES:-0}, full=${FULL:-0}, skip-apt=${SKIP_APT_UPDATE:-0})"

FAILED=()
SKIPPED=()

for ENTRY in "${SELECTED[@]}"; do
    SCRIPT="${ENTRY%%|*}"
    REST="${ENTRY#*|}"
    DESC="${REST%%|*}"
    DEFAULT="${REST##*|}"
    SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT"

    echo -e "${YELLOW}▶ ${SCRIPT}${RESET}"
    echo -e "   ${CYAN}${DESC}${RESET}"

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}   ❌ Script not found: $SCRIPT_PATH${RESET}\n"
        FAILED+=("$SCRIPT (missing)")
        record_run "$SCRIPT  missing"
        continue
    fi

    if [ -n "${DEBSWAY_FULL:-}" ]; then
        DEFAULT="Y"
    fi
    DEFAULT=${DEFAULT^^}
    PROMPT="   ➤ Run this script? (y/N): "
    [ "$DEFAULT" = "Y" ] && PROMPT="   ➤ Run this script? (Y/n): "

    if [ -n "${DEBSWAY_ASSUME_YES:-}" ]; then
        ANSWER="$DEFAULT"
        echo -e "${CYAN}   (unattended) → ${ANSWER}${RESET}"
    else
        read -rp "$PROMPT" ANSWER
        ANSWER=${ANSWER:-$DEFAULT}
    fi
    echo

    case "${ANSWER^^}" in
        Y)
            echo -e "${GREEN}   ✅ Running $SCRIPT...${RESET}"
            if bash "$SCRIPT_PATH"; then
                echo -e "${GREEN}   ✅ Done: $SCRIPT${RESET}\n"
                record_run "$SCRIPT  ok"
            else
                echo -e "${RED}   ❌ $SCRIPT exited with an error (continuing with the rest)${RESET}\n"
                FAILED+=("$SCRIPT")
                record_run "$SCRIPT  failed"
            fi
            ;;
        *)
            echo -e "${YELLOW}   ⚠ Skipped: $SCRIPT${RESET}\n"
            SKIPPED+=("$SCRIPT")
            record_run "$SCRIPT  skipped"
            ;;
    esac
done

# --- --verify: end-state audit --------------------------------------------
if [ "$DO_VERIFY" -eq 1 ]; then
    VERIFY_PATH="$SCRIPTS_DIR/verifySetup.sh"
    if [ -f "$VERIFY_PATH" ]; then
        echo -e "${BLUE}=========================================================${RESET}"
        echo -e "${BLUE}   🔍 Verifying setup...${RESET}"
        echo -e "${BLUE}=========================================================${RESET}\n"
        if bash "$VERIFY_PATH"; then
            record_run "verify  ok"
        else
            record_run "verify  issues"
        fi
    else
        echo -e "${YELLOW}⚠ verifySetup.sh not found — skipping --verify.${RESET}"
    fi
fi

echo -e "${BLUE}=========================================================${RESET}"
echo -e "${BLUE}   🏁 All tasks processed.${RESET}"
echo -e "${BLUE}=========================================================${RESET}"

if [ "${#SKIPPED[@]}" -gt 0 ]; then
    echo -e "${YELLOW}Skipped: ${SKIPPED[*]}${RESET}"
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
    echo -e "${RED}Failed:  ${FAILED[*]}${RESET}"
    echo -e "${YELLOW}Re-run individual scripts directly with: bash scripts/<name>.sh${RESET}"
    record_run "result  failed"
    exit 1
fi

echo -e "${GREEN}Done. A reboot is recommended (group membership + new services).${RESET}"
record_run "result  ok"
echo -e "${CYAN}Full log: $LOG_FILE${RESET}"