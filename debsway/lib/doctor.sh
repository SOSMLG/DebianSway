#!/usr/bin/env bash
# =======================================================
# debsway/lib/doctor.sh — `debsway doctor` self-check
# =======================================================
[ -n "${_DEBSWAY_LIB_DOCTOR_LOADED:-}" ] && return 0
_DEBSWAY_LIB_DOCTOR_LOADED=1

# needed_for <label> <cmd>
doctor_bin() {
    local label="$1" bin="$2"
    if command -v "$bin" >/dev/null 2>&1; then
        printf '  PASS  %-30s %s\n' "bin: $bin" "$(command -v "$bin")"
    else
        printf '  FAIL  %-30s not installed\n' "bin: $bin"
    fi
}

doctor_file() {
    local label="$1" file="$2"
    if [ -f "$file" ]; then
        printf '  PASS  %-30s %s\n' "cfg: $label" "$file"
    else
        printf '  WARN  %-30s missing\n' "cfg: $label"
    fi
}

doctor_run() {
    local t
    t="$(current_theme)"
    echo
    echo "DebSway doctor — $(command -v debsway || echo '?')"
    echo "  theme:      $t"
    echo "  state dir:  $DS_STATE"
    echo

    # binaries
    for b in sway swaybg swaylock swayidle waybar mako swayosd-server cliphist \
             swappy wlogout playerctl pamixer foot fuzzel grim slurp wf-recorder \
             kanshi gammastep wdisplays nwg-look qalc jq nmcli pactl thunar mpv \
             pipewire wireplumber pipewire-pulse; do
        doctor_bin "$b" "$b"
    done

    echo
    doctor_file "sway/config"        "$DS_CONFIG/sway/config"
    doctor_file "sway/colors.conf"  "$DS_CONFIG/sway/colors.conf"
    doctor_file "waybar/config"     "$DS_CONFIG/waybar/config"
    doctor_file "waybar/style.css"  "$DS_CONFIG/waybar/style.css"
    doctor_file "fuzzel/fuzzel.ini" "$DS_CONFIG/fuzzel/fuzzel.ini"
    doctor_file "foot/foot.ini"     "$DS_CONFIG/foot/foot.ini"
    doctor_file "mako/config"       "$DS_CONFIG/mako/config"
    doctor_file "swayosd/style.css" "$DS_CONFIG/swayosd/style.css"
    doctor_file "wlogout/style.css" "$DS_CONFIG/wlogout/style.css"
    doctor_file "kanshi/config"     "$DS_CONFIG/kanshi/config"
    doctor_file "gammastep/config.ini" "$DS_CONFIG/gammastep/config.ini"

    # token leak: ensure render produced no unresolved @@..@@ anywhere we render
    echo
    local leaked=0 f
    for f in "$DS_CONFIG"/sway/colors.conf "$DS_CONFIG"/waybar/style.css \
             "$DS_CONFIG"/fuzzel/fuzzel.ini "$DS_CONFIG"/foot/foot.ini \
             "$DS_CONFIG"/mako/config "$DS_CONFIG"/swayosd/style.css \
             "$DS_CONFIG"/wlogout/style.css; do
        [ -f "$f" ] || continue
        if grep -q '@@' "$f" 2>/dev/null; then
            printf '  FAIL  %-30s unresolved @@TOKEN@@\n' "render: $f"
            leaked=1
        fi
    done
    [ "$leaked" -eq 0 ] && printf '  PASS  %-30s no unresolved tokens\n' "render"

    # sway session state
    if is_under_sway; then
        printf '  PASS  %-30s session alive\n' "sway"
        if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
            printf '  PASS  %-30s %s\n' "session bus" "${DBUS_SESSION_BUS_ADDRESS:0:48}"
        else
            printf '  FAIL  %-30s missing — relogin via the "DebSway" greeter entry (raw sway has no bus; mako/portals/notify are dead)\n' "session bus"
        fi
        if [ -n "$(pgrep -x waybar)" ]; then
            printf '  PASS  %-30s running\n' "waybar"
        else
            printf '  WARN  %-30s not running\n' "waybar"
        fi
        [ -n "$(pgrep -x mako)" ]            && printf '  PASS  %-30s running\n' "mako"            || printf '  WARN  %-30s not running\n' "mako"
        [ -n "$(pgrep -x swayosd-server)" ]  && printf '  PASS  %-30s running\n' "swayosd-server"  || printf '  WARN  %-30s not running\n' "swayosd-server"
        [ -n "$(pgrep -x swayidle)" ]        && printf '  PASS  %-30s running\n' "swayidle"        || printf '  WARN  %-30s not running\n' "swayidle"
        [ -n "$(pgrep -x kanshi)" ]          && printf '  PASS  %-30s running\n' "kanshi"          || printf '  WARN  %-30s not running\n' "kanshi"
        if command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
            printf '  PASS  %-30s pipewire/pulse reachable\n' "audio"
        else
            printf '  WARN  %-30s not reachable — pipewire autostart in sway config\n' "audio"
        fi
        local layouts
        layouts="$(swaymsg -t get_inputs 2>/dev/null | jq -r '[.[]|select(.type=="keyboard")|.xkb_active_layout_name][0]')"
        echo "  info:       keyboard layout $layouts"
    else
        printf '  WARN  %-30s not running (ok if this is a headless check)\n' "sway"
    fi
    echo
}