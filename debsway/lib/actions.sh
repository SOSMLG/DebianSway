#!/usr/bin/env bash
# =======================================================
# debsway/lib/actions.sh — the actual commands behind `debsway`
# =======================================================
[ -n "${_DEBSWAY_LIB_ACTIONS_LOADED:-}" ] && return 0
_DEBSWAY_LIB_ACTIONS_LOADED=1

# --- menu / launcher ---------------------------------------------------------

cmd_launcher() {
    wofi --show drun --insensitive 2>/dev/null
}

cmd_menu() {
    local poweronly="$1"
    local labels=() cmds=()

    if [ -n "$poweronly" ]; then
        labels+=("\uf023  Lock screen");                 cmds+=("debsway lock")
        labels+=("\uf011  Power menu");                  cmds+=("wlogout -b 3")
        labels+=("\uf04e  Log out");                     cmds+=("swaymsg exit 2>/dev/null")
        labels+=("\uf2f2  Suspend");                     cmds+=("command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && systemctl suspend || { command -v loginctl >/dev/null 2>&1 && loginctl suspend || notify-send -u critical 'debsway' 'No suspend method available'; }")
        labels+=("\uf2f2  Reboot");                      cmds+=("command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && systemctl reboot || sudo reboot")
        labels+=("\uf011  Shutdown");                    cmds+=("command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && systemctl poweroff || sudo shutdown -h now")
    else
        labels+=("\uf0ae  Apps");                        cmds+=("debsway launcher")
        labels+=("\uf52e  Run command");                 cmds+=("wofi --show run")
        labels+=("\uf108  Display settings");            cmds+=("wdisplays")
        labels+=("\uf5fd  GTK look & feel");             cmds+=("nwg-look")
        labels+=("\uf53f  Switch theme");                cmds+=("debsway style")
        labels+=("\uf87c  Backgrounds");                 cmds+=("debsway bg panel")
        labels+=("\uf03e  Screenshot menu");             cmds+=("debsway shot menu")
        labels+=("\uf0ea  Clipboard history");           cmds+=("debsway clip")
        labels+=("\uf025  Audio devices");               cmds+=("debsway sound panel")
        labels+=("\uf1eb  Wi-Fi");                       cmds+=("debsway wire panel")
        labels+=("\uf186  Night light");                 cmds+=("debsway toggle night")
        labels+=("\uf628  Do not disturb");              cmds+=("debsway toggle dnd")
        labels+=("\uf6fb  Touchpad toggle");             cmds+=("debsway toggle touchpad")
        labels+=("\uf023  Lock screen");                 cmds+=("debsway lock")
        labels+=("\uf011  Power menu");                  cmds+=("wlogout -b 3")
        labels+=("\uf1ec  Calculator");                  cmds+=("debsway calc")
        labels+=("\uf021  Update system");               cmds+=("debsway update")
        labels+=("\uf0f0  System doctor");               cmds+=("debsway doctor")
        labels+=("\uf187  Coding agent");                cmds+=("debsway agent")
    fi

    local sel
    sel="$(printf '%s\n' "${labels[@]}" | wofi_pick "DebSway")" || return 1
    [ -z "$sel" ] && return 0
    local i=0
    for l in "${labels[@]}"; do
        if [ "$l" = "$sel" ]; then
            sh -c "${cmds[$i]}" >/dev/null 2>&1 &
            return 0
        fi
        ((i++))
    done
}

cmd_style() {
    local choice
    choice="$(printf '%s\n' "Switch theme" "Switch background" | wofi_pick "Style")" || return 1
    case "$choice" in
        *theme*)        cmd_theme_menu ;;
        *background*)   cmd_bg panel ;;
    esac
}

cmd_theme_menu() {
    local current cur1
    current="$(current_theme)"
    cur1="$current"
    local items=()
    local name
    for name in $(theme_list); do
        if [ "$name" = "$current" ]; then
            items+=("●  $name")
        else
            items+=("○  $name")
        fi
    done
    local sel
    sel="$(printf '%s\n' "${items[@]}" | wofi_pick "Theme (current: $cur1)")" || return 1
    [ -z "$sel" ] && return 0
    name="${sel#*  }"
    theme_set "$name"
}

cmd_bg() {
    local action="${1:-panel}" opt="${2:-}"
    local bg_dirs=("$DS_CONFIG/sway/wallpapers" "$HOME/Pictures/wallpapers" "$HOME/Pictures/Wallpapers")
    local imgs=()
    local d
    for d in "${bg_dirs[@]}"; do
        [ -d "$d" ] || continue
        while IFS= read -r -d '' f; do imgs+=("$f"); done \
            < <(find "$d" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0 2>/dev/null)
    done

    case "$action" in
        set|apply|cycle|random|reset|panel) ;;
        *) action="panel" ;;
    esac

    if [ "$action" = "set" ]; then
        local target="$opt"
        [ -f "$target" ] || target="$DS_CONFIG/sway/wallpapers/$opt"
        if [ -f "$target" ]; then
            _bg_apply "$target"
        else
            d_err "No such wallpaper: $opt"
        fi
        return
    fi

    if [ "$action" = "apply" ]; then
        local marker
        marker="$(get_marker bg)"
        [ -n "$marker" ] && [ -f "$marker" ] && _bg_apply "$marker"
        return
    fi

    if [ "$action" = "reset" ]; then
        rm -f "$DS_STATE/bg"
        _bg_apply "$DS_CONFIG/sway/wallpapers/catppuccin-mocha.png"
        return
    fi

    if [ "$action" = "cycle" ] || [ "$action" = "random" ]; then
        local cur next idx n
        cur="$(get_marker bg)"
        n="${#imgs[@]}"
        if [ "$action" = "random" ]; then
            next="$(printf '%s\n' "${imgs[@]}" | shuf -n1)"
        else
            idx=0
            while [ "$idx" -lt "$n" ]; do
                if [ "${imgs[$idx]}" = "$cur" ]; then
                    next="${imgs[$(((idx + 1) % n))]}"
                    break
                fi
                ((idx++))
            done
            [ -z "$next" ] && next="${imgs[0]}"
        fi
        [ -n "$next" ] && _bg_apply "$next"
        return
    fi

    # panel
    [ "${#imgs[@]}" -eq 0 ] && { d_warn "No wallpapers found in ${bg_dirs[*]}"; return 0; }
    local sel
    sel="$(printf '%s\n' "${imgs[@]}" | xargs -n1 basename | wofi_pick "Background")" || return 1
    [ -z "$sel" ] && return 0
    for f in "${imgs[@]}"; do
        [ "$(basename "$f")" = "$sel" ] && { _bg_apply "$f"; return; }
    done
}

_bg_apply() {
    local file="$1"
    set_marker bg "$file"
    if is_under_sway; then
        swaymsg "output * bg $file fill" >/dev/null 2>&1
        d_ok "Background set: $(basename "$file")"
    else
        d_warn "Not under sway — will apply at next session."
    fi
}

# --- power / lock ---------------------------------------------------------------

cmd_lock() {
    local paldir
    paldir="$(theme_dir "$(current_theme)")"
    load_palette "$paldir" 2>/dev/null || true
    local bg="${C_BG:-#11111b}" accent="${C_ACCENT:-#f38ba8}" crust="${C_CRUST:-#11111b}"
    command -v swaylock >/dev/null 2>&1 || { d_err "swaylock not installed."; return 1; }
    swaylock -f \
        -c "$bg" \
        --ring-color "$accent" \
        --inside-color "$crust" \
        --ring-clear-color "${C_GREEN:-#a6e3a1}" \
        --inside-clear-color "$crust" \
        --ring-ver-color "${C_BLUE:-#89b4fa}" \
        --inside-ver-color "$crust" \
        --ring-wrong-color "${C_RED:-#f38ba8}" \
        --inside-wrong-color "$crust" \
        --key-hl-color "$accent" \
        --bs-hl-color "$crust" \
        --line-color "$crust" \
        --separator-color "$crust" \
        --text-color "${C_TEXT:-#cdd6f4}" \
        --layout-text-color "${C_TEXT:-#cdd6f4}" \
        --indicator-radius 100 \
        --indicator-thickness 6
}

# --- agent ------------------------------------------------------------------------

cmd_agent() {
    case "${1:-run}" in
        status)
            if command -v opencode >/dev/null 2>&1; then
                echo "opencode  $(opencode --version 2>/dev/null)"
            else
                echo "opencode  not installed (run scripts/aiOpencode.sh)"
            fi
            ;;
        *)
            if command -v opencode >/dev/null 2>&1; then
                if [ -t 0 ]; then
                    # Already inside a terminal — run directly (no nested foot).
                    exec opencode "${@:2}"
                elif [ -z "${DISPLAY:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
                    # No tty + Wayland: open in a new alacritty window
                    # (foot does not render opencode's TUI correctly).
                    if command -v alacritty >/dev/null 2>&1; then
                        exec alacritty -e opencode "${@:2}"
                    else
                        exec opencode "${@:2}"
                    fi
                else
                    exec opencode "${@:2}"
                fi
            else
                d_err "OpenCode is not installed yet."
                d_log  "Install it with:  cd <repo> && bash scripts/aiOpencode.sh"
                return 1
            fi
            ;;
    esac
}

# --- clipboard ----------------------------------------------------------------------

cmd_clip() {
    local action="${1:-pick}"
    case "$action" in
        watch)
            command -v cliphist >/dev/null 2>&1 || { d_err "cliphist not installed."; return 1; }
            if cliphist help 2>&1 | grep -q '^\s*watch'; then
                    exec cliphist watch
                else
                    exec wl-paste --type text --watch cliphist store 2>/dev/null
            fi
            ;;
        clear)
            command -v cliphist >/dev/null 2>&1 || { d_err "cliphist not installed."; return 1; }
            [ -n "${2:-}" ] && printf '%s' "$2" | cliphist delete 2>/dev/null || cliphist wipe 2>/dev/null
            ;;
        pick|*)
            local sel
            sel="$(cliphist list 2>/dev/null | wofi_pick "Clipboard")" || return 1
            [ -z "$sel" ] && return 0
            printf '%s\n' "$sel" | cliphist decode | wl-copy
            ;;
    esac
}

# --- screenshots / recording -----------------------------------------------------------

SHOT_DIR="${SHOT_DIR:-$HOME/Pictures/screenshots}"

cmd_shot() {
    local action="${1:-menu}"
    mkdir -p "$SHOT_DIR"
    case "$action" in
        full)
            local f="$SHOT_DIR/shot-full-$(date +%Y%m%d-%H%M%S).png"
            grim "$f" && wl-copy < "$f" && notify "Screenshot saved" "$f"
            ;;
        area)
            local f="$SHOT_DIR/shot-area-$(date +%Y%m%d-%H%M%S).png"
            local g
            g="$(slurp 2>/dev/null)" || return 0
            grim -g "$g" "$f" && wl-copy < "$f" && notify "Screenshot saved" "$f"
            ;;
        annotate)
            local g
            g="$(slurp 2>/dev/null)" || return 0
            command -v swappy >/dev/null 2>&1 && grim -g "$g" - | swappy -f -
            ;;
        record)
            if pgrep -x wf-recorder >/dev/null 2>&1; then
                pkill -x wf-recorder; notify "Recording stopped"
            else
                local f="$SHOT_DIR/rec-$(date +%Y%m%d-%H%M%S).mp4"
                local g
                g="$(slurp 2>/dev/null)" || g=""
                # wf-recorder wants WxH+X+Y; slurp gives "x,y WxH".
                if [ -n "$g" ]; then
                    g="$(printf '%s' "$g" | sed 's/^\([0-9]*\),\([0-9]*\) \([0-9]*\)x\([0-9]*\)$/\3x\4+\1+\2/')"
                else
                    g="$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[]|select(.focused)|.rect|"\(.width)x\(.height)+\(.x)+\(.y)"' 2>/dev/null)"
                fi
                [ -n "$g" ] || g="1920x1080+0+0"
                notify "Recording" "Select an area to record…"
                setsid --fork bash -c "wf-recorder -g '$g' -f '$f'" >/dev/null 2>&1 &
                notify "Recording" "Playing: press Super+Ctrl+Print or run 'debsway shot record' to stop"
            fi
            ;;
        menu|*)
            local sel
            sel="$(printf '%s\n' \
                        "\uf030  Full screen" \
                        "\uf0b2  Screen region" \
                        "\uf304  Region + annotate" \
                        "\uf03d  Record area (toggle)" | wofi_pick "Screenshot")" || return 1
            case "$sel" in
                *Full*)    cmd_shot full ;;
                *region*)  cmd_shot area ;;
                *annotate*) cmd_shot annotate ;;
                *Record*)  cmd_shot record ;;
            esac
            ;;
    esac
}

# --- sound ----------------------------------------------------------------------------------

cmd_sound() {
    local action="${1:-panel}"
    case "$action" in
        up)   [ -x /usr/bin/swayosd-client ] && exec swayosd-client --output-volume +5 || pactl set-sink-volume @DEFAULT_SINK@ +5% ;;
        down) [ -x /usr/bin/swayosd-client ] && exec swayosd-client --output-volume -5 || pactl set-sink-volume @DEFAULT_SINK@ -5% ;;
        mute) [ -x /usr/bin/swayosd-client ] && exec swayosd-client --output-volume mute || pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
        panel|*)
            local sel choices=() cmds=() line idx name desc
            command -v pactl >/dev/null 2>&1 || { d_err "pactl not installed (pipewire-pulse)."; return 1; }
            mapfile -t sel < <(pactl list sinks short 2>/dev/null)
            for line in "${sel[@]}"; do
                idx=$(awk '{print $1}'   <<<"$line")
                name=$(awk '{print $2}'  <<<"$line")
                desc=$(pactl list sinks 2>/dev/null | awk -v idx="Sink #$idx" '$0==idx{c=1} c&&/Description:/{sub(/.*Description: /,""); print; exit}')
                desc="${desc:-$name}"
                choices+=("$desc")
                cmds+=("pactl set-default-sink $idx")
            done
            [ ${#choices[@]} -eq 0 ] && { d_warn "No audio sinks found."; return 1; }
            local picked i=0
            picked="$(printf '%s\n' "${choices[@]}" | wofi_pick "Audio output")" || return 1
            for name in "${choices[@]}"; do
                [ "$name" = "$picked" ] && { sh -c "${cmds[$i]}"; return 0; }
                ((i++))
            done
            ;;
    esac
}

# --- network ----------------------------------------------------------------------------------

cmd_wire() {
    local action="${1:-panel}"
    case "$action" in
        status)
            nmcli -t --fields TYPE,NAME,DEVICE con show --active 2>/dev/null | head -5
            ;;
        panel|*)
            command -v nmcli >/dev/null 2>&1 || { d_err "nmcli not installed (network-manager)."; return 1; }
            command -v python3 >/dev/null 2>&1 || { d_err "python3 not installed (needed for wifi panel)."; return 1; }
            nmcli dev wifi rescan >/dev/null 2>&1
            sleep 1
            local out
            out="$(nmcli --json dev wifi list 2>/dev/null)"
            local pick ssid
            pick="$(printf '%s\n' "$out" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin.read())
except Exception:
    sys.exit(0)
nets = d.get("device", {}).get("wifi", {}).get("networks", [])
seen = []
for n in nets:
    s = n.get("ssid")
    if not s or s in seen:
        continue
    seen.append(s)
    inuse = "●" if n.get("in-use") else "○"
    sig = n.get("signal") or 0
    bars = min(int(sig / 25) + 1, 4)
    print("%s %s\t%s" % (inuse, "\u2588" * bars + "\u2591" * (4 - bars), s))
' | wofi_pick "Wi-Fi")" || return 1
            [ -z "$pick" ] && return 0
            ssid="$(printf '%s\n' "$pick" | cut -f2)"
            notify "Connecting to" "$ssid"
            nmcli dev wifi connect "$ssid" >/dev/null 2>&1 \
                && notify "Connected" "$ssid" \
                || notify -u critical "Failed to connect" "$ssid"
            ;;
    esac
}

# --- toggles ------------------------------------------------------------------------------------

cmd_toggle() {
    local what="$1"
    case "$what" in
        night)
            if [ -f "$DS_STATE/night" ]; then
                rm -f "$DS_STATE/night"
                pkill -x gammastep 2>/dev/null
                gammastep -x >/dev/null 2>&1 || true
                notify "Night light" "off"
            else
                set_marker night on
                if command -v gammastep >/dev/null 2>&1; then
                    setsid --fork gammastep -c "$DS_CONFIG/gammastep/config.ini" >/dev/null 2>&1 &
                    notify "Night light" "on"
                else
                    d_err "gammastep not installed."
                    rm -f "$DS_STATE/night"
                fi
            fi
            ;;
        dnd)
            if command -v makoctl >/dev/null 2>&1; then
                if makoctl mode 2>/dev/null | grep -q dnd; then
                    makoctl mode -r dnd >/dev/null 2>&1
                    notify "Do Not Disturb" "off — notifications on"
                else
                    makoctl mode -a dnd >/dev/null 2>&1
                    notify "Do Not Disturb" "on — notifications muted"
                fi
            else
                d_err "makoctl not available (mako-notifier missing?)."
            fi
            ;;
        touchpad)
            is_under_sway || { d_err "Not running under sway."; return 1; }
            local tp
            tp="$(swaymsg -t get_inputs 2>/dev/null | jq -r '.[]|select(.type=="touchpad")|.input_identifier' 2>/dev/null | head -1)"
            swaymsg "input \"$tp\" events toggle" >/dev/null 2>&1
            local now
            now="$(swaymsg -t get_inputs 2>/dev/null | jq -r --arg t "$tp" '.[]|select(.input_identifier==$t)|.libinput.send_events' 2>/dev/null)"
            case "$now" in *disabled*) notify "Touchpad" "disabled";; *) notify "Touchpad" "enabled";; esac
            ;;
        layout)
            is_under_sway || { d_err "Not running under sway."; return 1; }
            swaymsg input type:keyboard xkb_switch_layout next >/dev/null 2>&1
            ;;
        *)
            d_err "Unknown toggle: $what (night|dnd|touchpad|layout)"
            return 1
            ;;
    esac
}

# --- misc -------------------------------------------------------------------------------------------

cmd_calc() {
    command -v qalc >/dev/null 2>&1 || { d_err "qalc not installed."; return 1; }
    local expr result
    expr="$(printf '\n' | wofi --show dmenu --insensitive --prompt "Calculate" 2>/dev/null)" || return 1
    [ -z "$expr" ] && return 0
    result="$(qalc -t "$expr" 2>/dev/null)"
    [ -n "$result" ] && { printf '%s\n' "$result"; wl-copy "$result" 2>/dev/null; }
}

cmd_date() {
    notify "Calendar" "$(cal -h 2>/dev/null | grep -v 'Calendar is highligh' || cal)"
}

cmd_bar() {
    case "$1" in
        restart)
            pkill -x waybar 2>/dev/null
            sleep 0.3
            setsid --fork waybar >/dev/null 2>&1 &
            ;;
        *) kill -HUP "$(pgrep -x waybar | head -1)" 2>/dev/null || true ;;
    esac
}

cmd_update() {
    local n fb=0
    n="$(apt list --upgradable 2>/dev/null | sed '1d' | grep -c '^')" || true
    command -v flatpak >/dev/null 2>&1 && fb="$(flatpak remote-ls --updates 2>/dev/null | wc -l)" || fb=0
    printf '  apt updates:    %s\n  flatpak updates: %s\n' "${n:-0}" "$fb"
    if [ "${n:-0}" -eq 0 ] && [ "$fb" -eq 0 ]; then
        d_ok "System up to date."
        return 0
    fi
    if [ "$1" = "--apply" ] || [ -n "${DEBSWAY_ASSUME_YES:-}" ]; then
        sudo apt-get upgrade -y
        [ "$fb" -gt 0 ] && { command -v sudo >/dev/null 2>&1 && sudo flatpak update -y || flatpak update -y; }
    else
        printf 'Run with --apply (or sudo apt-get upgrade) to install.\n'
    fi
}