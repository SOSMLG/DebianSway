# System context: Devuan (excalibur) + Sway

This machine was set up with `deb-sway-thinkpad`, a post-install toolkit for a
ThinkPad L14 Gen 2 AMD running Devuan 6 (excalibur) — binary-compatible with
Debian 13 (Trixie) — with the Sway Wayland compositor and a `debsway` CLI
layer on top. Keep the following in mind when suggesting commands or
diagnosing issues on this system:

## Package management
- **APT-based** (Devuan/Debian), not Arch/Fedora/Nix. Use `apt`/`apt-get`, never
  `pacman`, `dnf`, or `nix-env`.
- `apt-get install -y <pkg>` for installs, `apt-get purge -y <pkg>` to
  remove, `apt-get autoremove --purge -y` to clean up orphaned deps.
- **Backports are enabled natively** — Devuan ships `<suite>-backports`
  (`excalibur-backports`) from `deb.devuan.org/merged` in `/etc/apt/sources.list`;
  there is NO `deb.debian.org` backports line (that 404s). Install newer
  versions deliberately with `doas apt install -t excalibur-backports <pkg>` —
  never with a bare `apt upgrade`. Pinning lives in
  `/etc/apt/preferences.d/backports` (priority 100).
- Flatpak is available (`flatpak install flathub <app>`) as a secondary
  source if a package isn't in Devuan's repos. Browser is Firefox **ESR**
  (hardened with Betterfox + enterprise policies), not a flatpak.
- Repos: classic `/etc/apt/sources.list` uses Devuan's merged layout
  (`deb http://deb.devuan.org/merged excalibur ...`); third-party repos live in
  `/etc/apt/sources.list.d/` (deb822 `.sources` — e.g. Steam, VSCodium).

## Init system & services
- **OpenRC on sysvinit** (Devuan default), PID 1 is `/sbin/init`. There is
  **no `systemctl`/systemd** — enable/start services with
  `rc-update add <svc> default` and `rc-service <svc> start`, list with
  `rc-status`. User *session* bus is NOT provided by systemd; the graphical
  session is launched by **greetd+tuigreet** via a `dbus-run-session` wrapper
  (`/usr/local/bin/sway-session`) so `DBUS_SESSION_BUS_ADDRESS` reaches sway +
  apps (mako, portals, playerctl…). greetd is the active DM through
  `/etc/X11/default-display-manager`; SDDM stays installed as a fallback.

## Desktop environment
- **Sway** (Wayland tiling compositor), not GNOME/KDE/XFCE. This changes
  how you configure things:
  - Window manager + keybindings live in a single
    `~/.config/sway/config` (with `colors.conf` included for theme palette).
    Reload with `$mod+Shift+C`; sway reads this file live, there is no daemon.
  - Status bar is **Waybar** (`~/.config/waybar/config` + `style.css`, themed).
  - Launcher/menus are **fuzzel** (`debsway menu` palette, `debsway launcher`
    for apps, `debsway run` for plain commands), terminal is **foot**
    (`$term`, Wayland-native, Sway-authored), lockscreen
    is **swaylock** + **swayidle**, notifications are **mako**,
    volume/brightness OSD is **swayosd-server + swayosd-client**.
  - File manager is **Thunar** (+ `thunar-volman` automount, `gvfs-backends`
    for MTP/phones); TUI complement is **yazi** (`$mod+Shift+t`).
    Media is **mpv** (VLC optional fallback); docs are **zathura**.
    GUI anchors are Thunar + Firefox — everything else TUI-first.
  - Login manager is **greetd** with **tuigreet** (`/etc/greetd/config.toml`),
    not SDDM/GDM. Logging out lands you back on the greeter, not a TTY.
  - Global hotkeys are `bindsym` lines in the sway config — there is **no**
    `gsettings`, `kglobalaccel`, or `kwriteconfig`. E.g.
    `bindsym $mod+a exec $term -e debsway agent` (`$term` = foot).
  - Most desktop actions go through the **`debsway`** CLI (see below):
    `debsway menu|launcher|run|style|theme|bg|power|lock|agent|clip|shot|sound|
    wire|toggle|status|bar|update|doctor|setup`.
  - Screenshots: `grim` (full) / `grim -g "$(slurp)"` (region) /
    `swappy` (annotate) / `wf-recorder` (record) — or `debsway shot …`.
    Clipboard history: **cliphist** (`debsway clip pick/watch/clear`).
    Clipboard: `wl-copy`/`wl-paste`.
  - Night-light is **gammastep** (config `~/.config/gammastep/config.ini`),
    toggled with `debsway toggle night`. Auto display profiles: **kanshi**.
  - Per-device tuning for the touchpad/trackpoint goes in the `input`
    section of the sway config (`swaymsg -t get_inputs` to see devices),
    **not** `/etc/X11/xorg.conf.d` (Xorg config is ignored by sway).
  - The TrackPoint rides on `usbhid`; `/etc/modprobe.d/mousepoll.conf`
    sets `options usbhid mousepoll=2` for a snappier pointer.

## The `debsway` CLI
- Installed by `scripts/21-debsway-cli.sh` to `~/.local/share/debsway`
  (`bin/` router, `lib/` actions + theme engine + doctor + setup,
  `themes/` palettes + `_base/tpl` templates); symlinked from
  `~/.local/bin/debsway` **and** `/usr/local/bin/debsway` so sway binds can
  `exec debsway …`.
- Theming: `debsway theme set <name>` renders `themes/<name>/palette.sh`
  (hex without `#`) through the `_base/tpl` templates into `~/.config/`
  (sway, waybar, fuzzel, foot, mako, swayosd, wlogout) and
  soft-reloads waybar/mako/swayosd + `swaymsg reload`. Palettes:
  catppuccin-mocha-(red|blue), catppuccin-frappe, nord, dracula, tokyo-night,
  gruvbox-dark, solarized-dark.
- Persistent state (active theme, background, night-light) lives in
  `~/.local/state/debsway/` — **that's the marker to check**, not configs.
- `debsway doctor` is the one-command health check; `debsway setup` is the
  first-run wizard (theme/wallpaper/touchpad/night-light).

## Hardware notes (ThinkPad L14 Gen 2 AMD)
- **AMD Ryzen 5000U** — `amd64-microcode` + `firmware-amd-graphics` +
  `mesa-vulkan-drivers` installed. GPU is Vega (integrated, `amdgpu`);
  no proprietary driver needed.
- Battery/power is managed by **TLP** (`/etc/tlp.d/*.conf` for the 80%
  charge cap on `BAT0`). Don't install `power-profiles-daemon` alongside
  TLP — they fight.
- Wi-Fi firmware covers Intel AX200 / Realtek / MediaTek modules (the L14
  ships various). `iwlwifi`/`rtw89`/`mt7921e` all load out of the box once
  firmware is present.

## This toolkit's own conventions (for consistency if extending it)
- Scripts live in `scripts/`, each independently runnable
  (`bash scripts/<name>.sh`), all sourcing `scripts/lib/common.sh` for
  shared `ask()`/`log_*`/`install_pkgs` helpers.
- `run.sh` runs them in order; `install.sh` is the fully-unattended
  one-command wrapper (`run.sh --yes`). Env vars honored:
  `DEBSWAY_ASSUME_YES=1` (every prompt takes its default),
  `DEBSWAY_SKIP_APT_UPDATE=1` (skip per-script `apt-get update`).
- Every apt action checks what's actually installed first — nothing is
  blindly force-purged, so scripts are safe to re-run.
- Root escalation goes through the `priv()` helper (`scripts/lib/common.sh`,
  also mirrored in `debsway/lib/common.sh`): **doas** first, sudo fallback,
  override with `DEBSWAY_PRIV=doas|sudo`. Never write bare `sudo` in new
  code — and never "fix" `doas` back to `sudo`. Detached contexts without
  the helper (`sh -c` menu commands, wlogout `layout`) must call `doas`
  directly (helpers don't survive `exec` into a fresh shell).
- The default terminal is **foot**; keep `$term` references to foot
  in sway config and shell aliases consistent with that. The default picker
  is **fuzzel** (`fuzzel_pick` in `debsway/lib/common.sh` for text menus;
  `debsway launcher` uses fuzzel's native app mode, icons included).