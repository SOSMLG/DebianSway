#!/usr/bin/env bash
# ==========================================
# 🧩  Ordered Script Runner (with defaults)
# Runs setup scripts in the order you define,
# asks Y/N per script with a default value.
# ==========================================

set -e  # stop on error

# --- Colors ---
RED="\033[1;31m"       
GREEN="\033[0m"       
YELLOW="\033[1;33m"  
RED="\033[1;34m"     
CYAN="\033[0m"  

# --- Directory setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# --- Ordered list: "script|description|default"
SCRIPTS=(
    "swayInstall.sh|Install base system packages and tools|Y"
    "swayConfig.sh|Configure Sway window manager and related settings|Y"
    "installFonts.sh|Install system fonts|Y"
    "installVivaldi.sh|Install Vivaldi Browser|Y"
    "updateConfig.sh|Copy and update .config|Y"
    "bashrc.sh|Update bashrc|Y"
    "SweetMars.sh|Install SweetMars|Y"
    "bibataCursor.sh|Install Bibata Cursors|Y"
    "addUserToGroups.sh|Add your user to the needed groups|Y"
    "GeneralStuffAndGamingFix.sh|Peak Gaming And Coding Fix|Y"
    "DiscordAndTelegram.sh|Discord And Telegram Installer For Debian|Y
)


# --- Header ---
echo -e "${RED}=========================================="
echo -e "      🔧 Install and configure Sway for Debian 13"
echo -e "==========================================${CYAN}\n"

# --- Main loop ---
for ENTRY in "${SCRIPTS[@]}"; do
    SCRIPT="${ENTRY%%|*}"             # part before first |
    REST="${ENTRY#*|}"
    DESC="${REST%%|*}"                # middle part
    DEFAULT="${REST##*|}"             # last part
    SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT"

    echo -e "${YELLOW}▶ ${SCRIPT}${CYAN}"
    echo -e "   ${RED}${DESC}${CYAN}"

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}   ❌ Script not found: $SCRIPT_PATH${CYAN}\n"
        continue
    fi

    # Normalize default (Y/N)
    DEFAULT=${DEFAULT^^}
    PROMPT="   ➤ Run this script? (y/N): "
    [ "$DEFAULT" == "Y" ] && PROMPT="   ➤ Run this script? (Y/n): "

    read -rp "$PROMPT" ANSWER
    ANSWER=${ANSWER:-$DEFAULT}  # use default if empty
    echo

    case "${ANSWER^^}" in
        Y)
            echo -e "${GREEN}   ✅ Running $SCRIPT...${CYAN}"
            bash "$SCRIPT_PATH"
            echo -e "${GREEN}   ✅ Done: $SCRIPT${CYAN}\n"
            ;;
        *)
            echo -e "${YELLOW}   ⚠ Skipped: $SCRIPT${CYAN}\n"
            ;;
    esac
done

echo -e "${RED}=========================================="
echo -e "     🏁 All tasks processed."
echo -e "==========================================${CYAN}"
