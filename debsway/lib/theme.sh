#!/usr/bin/env bash
# =======================================================
# debsway/lib/theme.sh — the Theme Engine
# -------------------------------------------------------
# Mirrors Omarchy's "colors.toml compiler": one palette per
# theme, rendered into every app that has colors (sway,
# waybar, wofi, mako, foot, swayosd, wlogout, alacritty).
# Templates live in themes/_base/tpl/ with @@TOKEN@@
# placeholders; `debsway theme set` substitutes them from
# the palette and soft-reloads the running session.
# =======================================================
[ -n "${_DEBSWAY_LIB_THEME_LOADED:-}" ] && return 0
_DEBSWAY_LIB_THEME_LOADED=1

# render_palette <dir> <dst-root>
#  Renders every template under <dir>/themes/_base/tpl into <dst-root>,
#  preserving the relative path (e.g. sway/colors.conf -> <dst-root>/sway/...).
render_palette() {
    local dir="$1" dst="${2:-$DS_CONFIG}"
    load_palette "$dir" || return 1

    local tpl rel out
    local sedexpr=()
    local tok var
    # Build the sed expression once: @@TOKEN@@ -> value.
    # Hex values are stored WITHOUT '#'; templates add '#' when the consumer
    # wants CSS-style colors (foot & alacritty use bare / 0x forms).
    for tok in BG MANTLE CRUST SURFACE0 SURFACE1 SURFACE2 OVERLAY \
               TEXT SUBTEXT0 SUBTEXT1 ACCENT \
               RED GREEN YELLOW BLUE PURPLE PINK TEAL ORANGE \
               T0 T1 T2 T3 T4 T5 T6 T7 TB0 TB1 TB2 TB3 TB4 TB5 TB6 TB7; do
        var="C_$tok"
        sedexpr+=(-e "s|@@${tok}@@|${!var:-}|g")
    done

    while IFS= read -r -d '' tpl; do
        [ -f "$tpl" ] || continue
        rel="${tpl#"$DS_TPL"/}"
        out="$dst/$rel"
        mkdir -p "$(dirname "$out")"
        sed "${sedexpr[@]}" "$tpl" > "$out"
    done < <(find "$DS_TPL" -type f -print0)
    return 0
}

# theme_list — prints installed theme names, one per line
theme_list() {
    local t
    for t in "$DS_THEMES"/*/; do
        [ -d "$t" ] || continue
        [ -f "$t/palette.sh" ] || continue
        basename "$t"
    done
}

# theme_locked? helper used by doctor/apply — name of lock file touched.
theme_apply() {
    local name="$1" dst="${2:-$DS_CONFIG}"
    local dir
    dir="$(theme_dir "$name")"
    [ -d "$dir" ] || { d_err "Unknown theme: $name"; return 1; }
    render_palette "$dir" "$dst" || return 1
    set_marker theme "$name"
}

# theme_set <name> — render + persist + refresh session (used by router & menus)
theme_set() {
    theme_apply "$1" "${2:-$DS_CONFIG}" || return 1
    gtk_dark
    d_ok "Theme applied: $(current_theme)"
    theme_reload
}

# theme_reload — soft-reload the running sway session (best-effort)
theme_reload() {
    if is_under_sway; then
        swaymsg reload >/dev/null 2>&1 || true
        pkill -x waybar 2>/dev/null
        pkill -x mako 2>/dev/null
        pkill -x swayosd-server 2>/dev/null
        sleep 0.2
        command -v waybar >/dev/null 2>&1  && setsid --fork waybar >/dev/null 2>&1 &
        command -v mako >/dev/null 2>&1    && setsid --fork mako >/dev/null 2>&1 &
        command -v swayosd-server >/dev/null 2>&1 && setsid --fork swayosd-server >/dev/null 2>&1 &
        # swaylock picks up the new palette on next lock (debsway lock).
    fi
}

# gtk_dark — nudge GTK apps toward dark (matches the theme)
gtk_dark() {
    command -v gsettings >/dev/null 2>&1 || return 0
    export GSETTINGS_BACKEND=dconf 2>/dev/null
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark >/dev/null 2>&1 || true
}