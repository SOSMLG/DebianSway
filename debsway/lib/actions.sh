#!/usr/bin/env bash
# =======================================================
# debsway/lib/actions.sh — the actual commands behind `debsway`
# =======================================================
[ -n "${_DEBSWAY_LIB_ACTIONS_LOADED:-}" ] && return 0
_DEBSWAY_LIB_ACTIONS_LOADED=1

# --- menu / launcher ---------------------------------------------------------

cmd_launcher() {
    if ! command -v wofi >/dev/null 2>&1; then
        d_err "wofi is not installed (run scripts/10-sway-core.sh)."
        return 1
    fi
    wofi --show drun --insensitive
}

# --- keybinding cheat-sheet ----------------------------------------------------
# Parsed live from sway/config, so it can never go stale the way a
# hand-written list does. `debsway keys` opens the wofi picker,
# `debsway keys --list` prints plain text (terminal / grep / README gen).

_keys_config() {
    local c
    for c in "$DS_CONFIG/sway/config" /etc/skel/.config/sway/config; do
        if [ -f "$c" ]; then printf '%s\n' "$c"; return 0; fi
    done
    # Repo checkout without install: configs/ sits next to debsway/.
    if [ -n "${DEBSWAY_HOME:-}" ]; then
        c="$(cd "${DEBSWAY_HOME}/.." 2>/dev/null && pwd)/configs/sway/config"
        if [ -f "$c" ]; then printf '%s\n' "$c"; return 0; fi
    fi
    return 1
}

_keys_table() {  # prints "KEYSPEC<TAB>command" lines
    local cfg="$1" line mode="" keys cmd
    # Collect `set $var value` so $mod/$left/... resolve instead of
    # leaking raw `$left` into `debsway keys` output.
    declare -A _kv=()
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^[[:space:]]*set[[:space:]]+(\$[A-Za-z0-9_]+)[[:space:]]+(.*)$ ]]; then
            _kv["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        fi
    done < "$cfg"
    _expand_vars() {
        local s="$1" k
        for k in "${!_kv[@]}"; do
            s="${s//"$k"/"${_kv[$k]}"}"
        done
        # Normalize to the README's spelling: $mod (Mod4) displays as Super.
        s="${s//\$mod/Super}"
        s="${s//Mod4/Super}"
        printf '%s' "$s"
    }
    while IFS= read -r line || [ -n "$line" ]; do
        # Track `mode "name" {` blocks so resize binds are labeled.
        if [[ "$line" =~ ^[[:space:]]*mode[[:space:]]+\"([^\"]+)\" ]]; then
            mode="${BASH_REMATCH[1]}"
            continue
        fi
        [[ "$line" =~ ^[[:space:]]*\} ]] && { mode=""; continue; }
        [[ "$line" =~ ^[[:space:]]*bindsym[[:space:]]+(.*)$ ]] || continue
        line="${BASH_REMATCH[1]}"
        # Strip bindsym flags (--locked, --to-code, --input-device=*, ...).
        while [[ "$line" =~ ^--[a-z-]+(=([^[:space:]]+))?[[:space:]]+(.*)$ ]]; do
            line="${BASH_REMATCH[3]}"
        done
        keys="${line%%[[:space:]]*}"
        cmd="${line#*[[:space:]]}"
        cmd="$(printf '%s' "$cmd" | sed 's/[[:space:]]\+/ /g')"
        keys="$(_expand_vars "$keys")"
        cmd="$(_expand_vars "$cmd")"
        [ -n "$mode" ] && [ "$mode" != "default" ] && keys="[$mode] $keys"
        printf '%s\t%s\n' "$keys" "$cmd"
    done < "$cfg"
}

cmd_keys() {
    local cfg
    cfg="$(_keys_config)" || { d_err "No sway config found (expected $DS_CONFIG/sway/config)."; return 1; }
    if [ "${1:-}" = "--list" ] || ! command -v wofi >/dev/null 2>&1; then
        _keys_table "$cfg"
        return 0
    fi
    local sel
    sel="$(_keys_table "$cfg" | awk -F'\t' '{printf "%-28s  %s\n", $1, $2}' | wofi_pick "Keys (Super = \$mod)")" || return 1
    [ -z "$sel" ] && return 0
    # Copy the keyspec so it can be pasted into chat/notes.
    command -v wl-copy >/dev/null 2>&1 && printf '%s' "${sel%%  *}" | wl-copy 2>/dev/null || true
}

cmd_menu() {
    local poweronly="${1:-}"
    local labels=() cmds=()
    local _ds
    _ds="$(debsway_bin)"

    if [ -n "$poweronly" ]; then
        labels+=($'\uf023  Lock screen');                 cmds+=("$_ds lock")
        labels+=($'\uf011  Power menu');                  cmds+=("$_ds power")
        labels+=($'\uf04e  Log out');                     cmds+=("swaymsg exit")
        labels+=($'\uf2f2  Suspend');                     cmds+=("command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && systemctl suspend || { command -v loginctl >/dev/null 2>&1 && loginctl suspend || notify-send -u critical 'debsway' 'No suspend method available'; }")
        labels+=($'\uf2f2  Reboot');                      cmds+=("command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && systemctl reboot || { command -v loginctl >/dev/null 2>&1 && loginctl reboot || sudo -n reboot; }")
        labels+=($'\uf011  Shutdown');                    cmds+=("command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ] && systemctl poweroff || { command -v loginctl >/dev/null 2>&1 && loginctl poweroff || sudo -n shutdown -h now; }")
    else
        labels+=($'\uf0ae  Apps');                        cmds+=("$_ds launcher")
        labels+=($'\uf52e  Run command');                 cmds+=("wofi --show run")
        labels+=($'\uf108  Display settings');            cmds+=("wdisplays")
        labels+=($'\uf1fb  GTK look & feel');             cmds+=("nwg-look")
        labels+=($'\uf042  Switch theme');                cmds+=("$_ds style")
        labels+=($'\uf1c5  Backgrounds');                 cmds+=("$_ds bg panel")
        labels+=($'\uf03e  Screenshot menu');             cmds+=("$_ds shot menu")
        labels+=($'\uf0ea  Clipboard history');           cmds+=("$_ds clip")
        labels+=($'\uf025  Audio devices');               cmds+=("$_ds sound panel")
        labels+=($'\uf1eb  Wi-Fi');                       cmds+=("$_ds wire panel")
        labels+=($'\uf186  Night light');                 cmds+=("$_ds toggle night")
        labels+=($'\uf1f6  Do not disturb');              cmds+=("$_ds toggle dnd")
        labels+=($'\uf205  Touchpad toggle');             cmds+=("$_ds toggle touchpad")
        labels+=($'\uf023  Lock screen');                 cmds+=("$_ds lock")
        labels+=($'\uf011  Power menu');                  cmds+=("$_ds power")
        labels+=($'\uf11c  Keybindings');                cmds+=("$_ds keys")
        labels+=($'\uf021  Update system');               cmds+=("$_ds update")
        labels+=($'\uf0f0  System doctor');               cmds+=("$_ds doctor")
        labels+=($'\uf187  Coding agent');                cmds+=("$_ds agent")
    fi

    local sel
    sel="$(printf '%s\n' "${labels[@]}" | wofi_pick "DebSway")" || return 1
    [ -z "$sel" ] && return 0
    local i=0
    for l in "${labels[@]}"; do
        if [ "$l" = "$sel" ]; then
            case "$sel" in
                *"Update system"|*"System doctor")
                    # Report-style entries: when picked from a keybind there
                    # is no tty, so detached stdout vanishes unheard — open
                    # them in a terminal that waits before closing.
                    if [ ! -t 1 ]; then
                        _tb="$(term_bin)" || _tb=""
                        if [ -n "$_tb" ]; then
                            setsid --fork "$_tb" -e sh -c "${cmds[$i]}; printf '\n-- done — press Enter to close --\n'; read -r _" >/dev/null 2>&1 &
                            disown 2>/dev/null || true
                            return 0
                        fi
                    fi
                    ;;
            esac
            # In a terminal run foreground so output/errors stay visible;
            # from a keybind (no tty) detach so the menu closes immediately.
            if [ -t 1 ]; then
                sh -c "${cmds[$i]}"
                return $?
            fi
            setsid --fork sh -c "${cmds[$i]}" >/dev/null 2>&1 &
            disown 2>/dev/null || true
            return 0
        fi
        i=$((i + 1))
    done
    d_warn "No match for selection: $sel"
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
        if [ -n "$marker" ] && [ -f "$marker" ]; then
            _bg_persist "$marker"
            if is_under_sway; then
                swaymsg "output * bg \"$marker\" fill" >/dev/null 2>&1
            fi
        fi
        return
    fi

    if [ "$action" = "reset" ]; then
        rm -f "$DS_STATE/bg"
        _bg_apply "$DS_CONFIG/sway/wallpapers/catppuccin-mocha.png"
        return
    fi

    if [ "$action" = "cycle" ] || [ "$action" = "random" ]; then
        local cur="" next="" idx n
        cur="$(get_marker bg)"
        n="${#imgs[@]}"
        [ "$n" -eq 0 ] && { d_warn "No wallpapers found."; return 0; }
        if [ "$action" = "random" ]; then
            next="$(printf '%s\n' "${imgs[@]}" | shuf -n1)"
        else
            idx=0
            while [ "$idx" -lt "$n" ]; do
                if [ "${imgs[$idx]}" = "$cur" ]; then
                    next="${imgs[$(((idx + 1) % n))]}"
                    break
                fi
                idx=$((idx + 1))
            done
            [ -z "$next" ] && next="${imgs[0]}"
        fi
        [ -n "$next" ] && _bg_apply "$next"
        return
    fi

    # panel
    [ "${#imgs[@]}" -eq 0 ] && { d_warn "No wallpapers found in ${bg_dirs[*]}"; return 0; }
    local sel names=() f
    for f in "${imgs[@]}"; do names+=("$(basename "$f")"); done
    sel="$(printf '%s\n' "${names[@]}" | wofi_pick "Background")" || return 1
    [ -z "$sel" ] && return 0
    for f in "${imgs[@]}"; do
        [ "$(basename "$f")" = "$sel" ] && { _bg_apply "$f"; return; }
    done
}

_bg_persist() {
    # Rewrite the `output * bg ...` line in sway/config so `swaymsg reload`
    # ($mod+Shift+C) and theme reloads keep the chosen wallpaper instead of
    # snapping back to the baked-in default.
    local file="$1" cfg="$DS_CONFIG/sway/config"
    [ -f "$cfg" ] || return 0
    # Escape sed replacement chars in the path.
    local esc
    esc="$(printf '%s' "$file" | sed 's/[&|\\]/\\&/g')"
    if grep -qE '^[[:space:]]*output[[:space:]]+\*[[:space:]]+bg[[:space:]]' "$cfg"; then
        sed -i -E "s|^[[:space:]]*output[[:space:]]+\\*[[:space:]]+bg[[:space:]]+.*|output * bg $esc fill|" "$cfg"
    else
        printf '\noutput * bg %s fill\n' "$file" >> "$cfg"
    fi
}

_bg_apply() {
    local file="$1"
    set_marker bg "$file"
    _bg_persist "$file"
    if is_under_sway; then
        swaymsg "output * bg \"$file\" fill" >/dev/null 2>&1
        d_ok "Background set: $(basename "$file") (persisted across reload)"
    else
        d_warn "Not under sway — saved, will apply at next session (debsway bg apply)."
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
                echo "opencode  not installed (run scripts/34-opencode-agent.sh)"
            fi
            ;;
        *)
            if command -v opencode >/dev/null 2>&1; then
                [ $# -gt 0 ] && shift
                if [ -t 0 ]; then
                    # Already inside a terminal — run directly (no nesting).
                    exec opencode "$@"
                elif [ -z "${DISPLAY:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ]; then
                    # No tty + Wayland: open in a new alacritty window
                    # (Alacritty is the canonical $term; it renders
                    # opencode's TUI correctly).
                    if command -v alacritty >/dev/null 2>&1; then
                        exec alacritty -e opencode "$@"
                    else
                        exec opencode "$@"
                    fi
                else
                    exec opencode "$@"
                fi
            else
                d_err "OpenCode is not installed yet."
                d_log  "Install it with:  cd <repo> && bash scripts/34-opencode-agent.sh"
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
            command -v slurp >/dev/null 2>&1 || { d_err "slurp not installed."; return 1; }
            g="$(slurp)" || return 0
            grim -g "$g" "$f" && wl-copy < "$f" && notify "Screenshot saved" "$f"
            ;;
        annotate)
            local g
            command -v slurp >/dev/null 2>&1 || { d_err "slurp not installed."; return 1; }
            g="$(slurp)" || return 0
            command -v swappy >/dev/null 2>&1 && grim -g "$g" - | swappy -f -
            ;;
        record)
            if pgrep -x wf-recorder >/dev/null 2>&1; then
                pkill -x wf-recorder; notify "Recording stopped"
            else
                local f="$SHOT_DIR/rec-$(date +%Y%m%d-%H%M%S).mp4"
                local g
                notify "Recording" "Drag a region to record (Esc = full output)…"
                g="$(slurp)" || g=""
                # wf-recorder wants WxH+X+Y; slurp gives "x,y WxH".
                if [ -n "$g" ]; then
                    g="$(printf '%s' "$g" | sed 's/^\([0-9]*\),\([0-9]*\) \([0-9]*\)x\([0-9]*\)$/\3x\4+\1+\2/')"
                else
                    g="$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[]|select(.focused)|.rect|"\(.width)x\(.height)+\(.x)+\(.y)"' 2>/dev/null)"
                fi
                [ -n "$g" ] || g="1920x1080+0+0"
                setsid --fork wf-recorder -g "$g" -f "$f" >/dev/null 2>&1 &
                notify "Recording" "Started — press Super+Ctrl+Print or run 'debsway shot record' to stop"
            fi
            ;;
        menu|*)
            local sel
            sel="$(printf '%s\n' \
                        $'\uf030  Full screen' \
                        $'\uf0b2  Screen region' \
                        $'\uf304  Region + annotate' \
                        $'\uf03d  Record area (toggle)' | wofi_pick "Screenshot")" || return 1
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

# _sound_osd <swayosd-client args...> — true iff the OSD accepted the command
_sound_osd() {
    command -v swayosd-client >/dev/null 2>&1 || return 1
    pgrep -x swayosd-server >/dev/null 2>&1 || return 1
    swayosd-client "$@" >/dev/null 2>&1
}

cmd_sound() {
    local action="${1:-panel}"
    # Prefer the swayosd OSD, but only when its server is actually reachable:
    # a bare `exec swayosd-client` with a dead server would swallow the pactl
    # fallback (exec replaces the shell), leaving the key dead. So try the
    # client first and fall back to pactl on failure.
    case "$action" in
        up)   _sound_osd --output-volume +5    || pactl set-sink-volume @DEFAULT_SINK@ +5% ;;
        down) _sound_osd --output-volume -5    || pactl set-sink-volume @DEFAULT_SINK@ -5% ;;
        mute) _sound_osd --output-volume mute  || pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
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
            [ "${#choices[@]}" -eq 0 ] && { d_warn "No audio sinks found."; return 1; }
            local picked i=0
            picked="$(printf '%s\n' "${choices[@]}" | wofi_pick "Audio output")" || return 1
            for name in "${choices[@]}"; do
                [ "$name" = "$picked" ] && { sh -c "${cmds[$i]}"; return 0; }
                i=$((i + 1))
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
            nmcli dev wifi rescan >/dev/null 2>&1
            sleep 1
            # Terse output works on every nmcli (unlike --json, which older
            # NetworkManager builds reject with "Option '--json' is unknown").
            local rows pick ssid
            rows="$(nmcli -t -f IN-USE,SIGNAL,SSID dev wifi list 2>/dev/null \
                | awk -F: '!seen[$3]++ && $3 != "" {
                    inuse=($1=="*") ? "●" : "○";
                    sig=$2+0; bars=int(sig/25)+1; if (bars<1) bars=1; if (bars>4) bars=4;
                    bar=""; for (i=0;i<bars;i++) bar=bar "█"; for (i=bars;i<4;i++) bar=bar "░";
                    printf "%s %s\t%s\n", inuse, bar, $3
                }')"
            [ -n "$rows" ] || { d_warn "No Wi-Fi networks found."; return 0; }
            pick="$(printf '%s\n' "$rows" | wofi_pick "Wi-Fi")" || return 1
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
    local what="${1:-}"
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

cmd_bar() {
    case "${1:-reload}" in
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
    if [ "${1:-}" = "--apply" ] || [ -n "${DEBSWAY_ASSUME_YES:-}" ]; then
        sudo apt-get upgrade -y
        [ "$fb" -gt 0 ] && { command -v sudo >/dev/null 2>&1 && sudo flatpak update -y || flatpak update -y; }
    else
        printf 'Run with --apply (or sudo apt-get upgrade) to install.\n'
    fi
}