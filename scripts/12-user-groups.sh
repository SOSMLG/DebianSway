#!/usr/bin/env bash
# DEBSWAY_DESC: Add your user to device groups + ensure a doas rule
# DEBSWAY_DEFAULT: Y
# Add the real (non-root) user to groups needed by the rest of this toolkit:
#   input   -> required for some touchpad/trackpoint tools & libinput debugging
#   video   -> GPU/brightness access
#   render  -> GPU compute/accel access (DRI render nodes)
#   plugdev -> USB sticks, MTP/Android, cameras, iOS (udev rules use plugdev)
# Plus: ensure one working privilege path exists (doas preferred, sudo
# fallback) by adding a doas rule when escalation currently looks broken.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Get actual user even when this was invoked via doas/sudo somewhere upstream
ACTUAL_USER="${SUDO_USER:-${DOAS_USER:-$USER}}"

if [ -z "$ACTUAL_USER" ] || [ "$ACTUAL_USER" = "root" ]; then
    echo -e "${RED}Could not determine a non-root user to modify. Aborting.${NC}"
    exit 1
fi

echo -e "Adding ${YELLOW}${ACTUAL_USER}${NC} to input, video, render, plugdev groups..."

status=0
for grp in input video render plugdev; do
    if ! getent group "$grp" >/dev/null 2>&1; then
        echo -e "${YELLOW}  Group '$grp' does not exist on this system, skipping.${NC}"
        continue
    fi
    if id -nG "$ACTUAL_USER" 2>/dev/null | tr ' ' '\n' | grep -qx "$grp"; then
        echo -e "${GREEN}  Already in '$grp'${NC}"
        continue
    fi
    if priv usermod -aG "$grp" "$ACTUAL_USER"; then
        echo -e "${GREEN}  ✓ Added to '$grp'${NC}"
    else
        echo -e "${RED}  ✗ Failed to add to '$grp'${NC}"
        status=1
    fi
done

echo -e "${YELLOW}⚠ You need to log out and back in (or reboot) for new group membership to take effect.${NC}"

# ---------------------------------------------------------------------------
# doas rule (BSD-minimal privilege path). doas.conf semantics (doas.conf(5)):
# last match wins, default deny — so one explicit line is the whole policy:
#   permit persist <you> as root
# `persist` caches one successful auth for a few minutes (no password
# spam during a toolkit run); nothing is logged away (no nolog).
# ---------------------------------------------------------------------------
DOAS_CONF="/etc/doas.conf"
if [ -f "$DOAS_CONF" ] && grep -qw "$ACTUAL_USER" "$DOAS_CONF" 2>/dev/null; then
    echo -e "${GREEN}  doas already names '$ACTUAL_USER' ($DOAS_CONF)${NC}"
elif id -nG 2>/dev/null | grep -qwE "sudo|wheel|doas"; then
    echo -e "${GREEN}  privilege path OK (group sudo/wheel/doas)${NC}"
elif ask "No working privilege path detected — add 'permit persist $ACTUAL_USER as root' to $DOAS_CONF?"; then
    if [ -f "$DOAS_CONF" ]; then
        priv cp -a "$DOAS_CONF" "$DOAS_CONF.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    if printf 'permit persist %s as root\n' "$ACTUAL_USER" | priv tee -a "$DOAS_CONF" >/dev/null \
        && priv chmod 600 "$DOAS_CONF" 2>/dev/null; then
        echo -e "${GREEN}  ✓ doas rule added (root-owned, mode 600)${NC}"
    else
        echo -e "${RED}  ✗ Could not write $DOAS_CONF (no working escalator).${NC}"
        echo -e "${YELLOW}  As root, run: printf 'permit persist $ACTUAL_USER as root\n' > $DOAS_CONF${NC}"
        echo -e "${YELLOW}  then relogin and re-run this script.${NC}"
        status=1
    fi
else
    echo -e "${YELLOW}  Skipped doas setup — later scripts will fail at their first priv step.${NC}"
fi

exit "$status"
