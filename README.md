# deb-sway-thinkpad

A post-install toolkit that turns a fresh **Devuan 6 (Excalibur)** install
(binary-compatible with **Debian 13 (Trixie)**) into a
**Sway (Wayland)** desktop for a **ThinkPad L14 Gen 2 AMD** — Catppuccin
**Mocha/Red** themed, Firefox ESR hardened, TLP battery-capped, and installable
with **one command, fully unattended**.

Built from two sources: the configs/notes of `debian_sway-main` (a T14 Gen 2
Intel Sway guide) and the script runner + post-install toolkit of
`Devuan-Kde-main` (KDE/Plasma), adapted for Sway and the AMD hardware.

```
./install.sh        # everything, unattended, verified — that's it
./run.sh --list     # see every step in order, defaults and all
./run.sh            # pick-and-choose interactively
```

You run it as your **normal user** (never `doas bash install.sh`); each script
escalates itself (`doas`, `sudo` fallback) for the parts that need it.

---

## Quick start

On a fresh Devuan 6 (Excalibur) / Debian 13 (Trixie) install, with the brew role done and internet up:

```bash
# 1. Clone + run
git clone <this-repo> && cd deb-sway-thinkpad
./install.sh
# ~everything, then a verification report; reboot when it finishes

# 2. Reboot — greetd/tuigreet gives you a login screen
#    (systemd: `systemctl reboot`; Devuan/OpenRC: `doas reboot`)
```

`install.sh` = `run.sh --full --verify`: every step answers **yes**, including
the optional groups (VSCodium, gaming, Vesktop/Telegram, PhotoGIMP, dev tools).
Variants:

| Command | What it does |
|---|---|
| `./install.sh --core` | Core Sway desktop only, skips optional groups |
| `./run.sh --yes` | Everything, but only the default-Y steps (no optional groups) |
| `./run.sh --phase core,desktop` | Only the core + desktop phases |
| `./run.sh --only firefox,useful-apps` | Just those steps (short names work) |
| `./run.sh --no-update` | Skip the runner's single `apt-get update` |

Install with `bash -x ./install.sh` to watch every step, if you're curious or
something looks off.

### Minimal Debian netinst notes

Two things a bare netinst often lacks — handle them before `./install.sh`:

* **Privilege for your user.** Either leave the root password **empty** during
  install (Debian then puts your user in `sudo`), or afterwards as root:
  ```bash
  apt install -y sudo opendoas && usermod -aG sudo <you>
  printf 'permit persist <you> as root\n' > /etc/doas.conf
  ```
  then **relogin**. The toolkit refuses to run as root and warns early if
  escalation can't work — but it can't test your password for you, so a wrong
  setup fails mid-run at the first privileged step.
* **Firmware component.** Prefer an installer image that includes
  non-free-firmware (otherwise WiFi may not even work for the install). If
  the component is missing afterwards, script `13-hardware.sh` enables it
  itself (`ensure_repo_component`) instead of skipping firmware.

Everything else is automatic across both distros: backports branch (Debian
`.sources` file vs Devuan merged), PAM provider (`libpam-systemd` vs
`libpam-elogind`), service handling (systemd unit vs sysvinit script), and
the greetd login. If a niche package ever goes missing from trixie,
`verifySetup.sh` reports it per-package, loudly, instead of failing obscurely.

---

## What you get

| Layer | Choice |
|---|---|
| Window manager | **Sway** (Wayland) via **greetd + tuigreet** login (SDDM stays installed only as a manual fallback, never auto-started) |
| Shell layer | **swayosd** OSD, **cliphist** clipboard history, **swappy**/grim/wf-recorder capture, waybar now-playing via **playerctl**, **gammastep** night-light, **kanshi** auto display profiles |
| Theme | **`debsway theme set`** engine (Omarchy-style): 8 one-shot palettes (Catppuccin Mocha/Red default, Mocha/Blue, Frappe, Nord, Dracula, Tokyo Night, Gruvbox, Solarized) compiled into sway/waybar/fuzzel/foot/mako/swayosd/wlogout. Catppuccin Mocha Red cursor pack + red gradient wallpaper |
| Terminal | **foot** (Wayland-native Sway-authored terminal — `set $term foot` in `configs/sway/config`; themed via `~/.config/foot/foot.ini`; `debsway agent` also opens here; `fuzzel` uses `terminal=foot -e`) |
| Launcher/menu | **fuzzel** driving the `debsway` command palette (`$mod+d` → `debsway menu`, `$mod+Shift+d` → `fuzzel`, waybar ☰ → `debsway menu`) |
| Files | **Thunar** (+ volman automount, `gvfs-backends` for MTP/phones) + **yazi** TUI (`$mod+Shift+t`) |
| Media/docs | **mpv** (VLC fallback), **zathura** PDF, **swayimg** images |
| Browser | **Firefox ESR** hardened with Betterfox-derived preferences + a locked `policies.json` |
| Shell | **ButterBash**: saner bash (aliases, history, `eza`/`bat` where present) |
| Input | libinput: tap-to-click on, natural scroll off (baked into `sway/config`) |
| Battery | **TLP** + 80% charge cap via `charge_control_end_threshold` (thinkpad_acpi) |
| Bluetooth | **Blueman** applet (A2DP), not bluedevil |
| GPU | amdgpu + `mesa-vulkan-drivers` + `firmware-amd-graphics` |
| Software | Flatpak/Flathub, CUPS, gufw/ufw, mpv (VLC fallback), codecs, GIMP, Timeshift, OpenCode, pass/KeePassXC, btop/eza/bat/zoxide/yazi |

### Scripts — phases in run order (`./run.sh --list` is authoritative)

| Phase | Script | Default |
|---|---|---|
| core | `10-sway-core.sh` — Sway stack + greetd login + Flatpak + configs | Y |
| core | `11-backports.sh` — backports + apt pinning | Y |
| core | `12-user-groups.sh` — `input`/`video`/`render`/`plugdev` groups | Y |
| core | `13-hardware.sh` — WiFi/BT/AMD firmware, microcode, fwupd | Y |
| core | `14-bluetooth.sh` — Bluetooth stack + Blueman | Y |
| core | `15-codecs.sh` — audio/video codecs + DVD | Y |
| core | `16-firefox.sh` — Firefox ESR + Betterfox hardening | Y |
| core | `17-fonts.sh` — Noto, Font Awesome, JetBrainsMono Nerd Font | Y |
| core | `18-butterbash.sh` — ButterBash | Y |
| core | `19-fastfetch.sh` — fastfetch + config presets | Y |
| desktop | `20-shell-upgrade.sh` — OSD, clipboard, screenshots, media keys, night-light, foot + fuzzel | Y |
| desktop | `21-debsway-cli.sh` — DebSway CLI + theme engine | Y |
| desktop | `22-theme-default.sh` — Catppuccin Mocha/Red + cursor | Y |
| apps | `30-desktop-essentials.sh` — Flatpak, CUPS, firewall, gparted | Y |
| apps | `31-timeshift.sh` — Timeshift snapshots | Y |
| apps | `32-time-sync.sh` — chrony NTP time sync | N |
| apps | `33-useful-apps.sh` — mpv (+ VLC fallback), zathura, TLP + battery cap, archives | Y |
| apps | `34-opencode-agent.sh` — OpenCode AI agent + `$mod+a` hotkey | Y |
| optional | `40-vscodium.sh` — VSCodium | N |
| optional | `41-dev-essentials.sh` — Fully-suited dev station: TUI tools + C/C++ + Python, no editor | Y |
| optional | `43-photogimp.sh` — GIMP + PhotoGIMP layout | N |
| optional | `44-gaming.sh` — Heroic/Steam/Wine | N |
| optional | `45-chat.sh` — Vesktop (Discord) / Telegram | N |
| optional | `46-neovim.sh` — Neovim (Debian apt 0.10) + LazyVim v14 pinned config | N |
| utils | `50-maintenance.sh` — apt cleanup | N |
| utils | `51-backup.sh` — config backup (timestamped archive) | N |
| utils | `52-skel-export.sh` — per-user defaults to `/etc/skel` | N |

---

## Backports (`scripts/11-backports.sh`)

Debian **trixie currently ships Sway beyond oldstable** so most pins we need are
already in Trixie, but the toolkit still:

* adds `/etc/apt/sources.list.d/debian-backports.sources` (deb822, same codename
  as your `/etc/os-release`) — new packages get newer versions when pulled via
  the pin,
* writes `/etc/apt/preferences.d/backports` with priority **100**, so nothing is
  upgraded automatically and only explicitly requested backports packages land.

Always toggleable: edit `run.sh`'s list and answer N, or remove the file later.

---

## Hardware notes (L14 Gen 2 AMD, Ryzen 5000U)

* **GPU (Vega iGPU)**: amdgpu kernel driver + `firmware-amd-graphics` +
  `mesa-vulkan-drivers`. Sway, Vulkan and VA-API hardware decode work out of
  the box.
* **WiFi/BT**: a bunch of firmware packages are pulled (`firmware-misc-nonfree`,
  `firmware-iwlwifi`, `firmware-realtek`, `firmware-mt76`, etc.) so whatever
  SKU your unit has — Intel AX200 / Realtek / MediaTek — is covered.
* **Input**: `/dev/input` needs your user in the `input` group (script 02), and
  the sway config sets libinput tap-to-click + palm detection + no natural
  scroll. TrackPoint is configured there too.
* **Battery care**: TLP, then a charge cap to 80% — works on batteries exposing
  `charge_control_end_threshold` (thinkpad_acpi, L14 G2 AMD does expose it).
* **Secure Boot**: this toolkit doesn't sign anything. If SB is on, kernel
  modules (amdgpu etc.) load fine, but keep your distro's lock/kernel approach;
  if unsure, set Secure Boot to Setup Mode or off in BIOS before first real use.

### Keyboard (`$mod = Super` — matches `configs/sway/config` 1:1)

| Keys | Action |
|---|---|
| `$mod+Return` | Terminal (foot via `$term` — `set $term foot`) |
| `$mod+d` / `$mod+Shift+d` | DebSway command palette (`debsway menu`, `$menu`) / run dialog (`fuzzel`) |
| `$mod+a` | Coding agent (`$term -e debsway agent` → foot + OpenCode) |
| `$mod+t` / `$mod+Shift+t` / `$mod+z` | File manager (`thunar`) / TUI files (`foot -e yazi`) / browser (`firefox`) |
| `$mod+Shift+q` | Kill focused window |
| `$mod+v` | Clipboard history (`debsway clip pick` → cliphist + fuzzel) |
| `$mod+slash` | Keybinding cheat-sheet (`debsway keys`, parsed live from sway config) |
| `Print` / `$mod+Print` / `$mod+Ctrl+Print` | Screenshot full / area / screen-record toggle (`debsway shot …` — saves to `~/Pictures/screenshots`, copies to clipboard, notifies) |
| `$mod+Escape` / `$mod+Ctrl+p` | Power menu (`debsway power` → wlogout grid) |
| `$mod+x` | Lock screen (`debsway lock` — themed swaylock; note `$mod+l` is vim-nav *focus right*, not lock) |
| `$mod+Shift+e` | Exit sway (swaynag confirm → back to greetd) |
| `XF86AudioMute/LowerVolume/RaiseVolume` | Volume mute/down/up via `debsway sound …` (swayosd OSD when available, `pactl` fallback) |
| `XF86AudioMicMute` | Mic mute (`pactl`) |
| `XF86MonBrightnessDown/Up` | Backlight 5% steps (`brightnessctl`) |
| `XF86AudioPlay/Next/Prev` | Media play-pause / next / previous (`playerctl`) |
| `$mod+m` | Fullscreen toggle |
| `$mod+Shift+o` | Layout toggle (tabbed / splitv / splith) |
| `$mod+b` / `$mod+Shift+v` | Split horizontal / vertical |
| `$mod+space` / `$mod+Shift+space` | Toggle floating (+ center + 70×75% resize) / re-center + resize floating window to 70×75% |
| `$mod+Shift+y` | Center floating window (no resize) |
| `$mod+Shift+f` / `$mod+n` | Focus mode toggle (tiling ↔ floating focus) |
| `$mod+h/j/k/l` + arrows | Focus left/down/up/right (vim + arrows) |
| `$mod+Shift+h/j/k/l` + arrows | Move window left/down/up/right |
| `$mod+u` / `$mod+i` | Focus parent / child |
| `$mod+Tab` / `Alt+Tab` | Next / previous workspace on output |
| `$mod+Shift+n` / `$mod+Shift+p` | Cycle fullscreened windows next / prev |
| `$mod+Shift+minus` / `$mod+minus` | Move to scratchpad / show scratchpad |
| `$mod+alt+r` then `h/j/k/l`, `Return`/`Escape` | Resize mode (20px / 5ppt steps, confirm / abort) |
| `$mod+1…9,0` | Switch to workspace 1…10 |
| `$mod+Shift+1…9,0` | Move container to workspace 1…10 |
| `Alt+Shift` | Keyboard layout toggle (us ⇄ th, configured in `input type:keyboard`) |
| swipe right/left/up/down (touchpad) | Focus next/prev, workspace prev/next (gestures) |
| `$mod+Shift+c` | Reload sway config |
| button4 / button5 (titlebar scroll) | Disabled (`nop`) |

---

## The `debsway` CLI

Every desktop-surface action lives behind one command (installed by
`21-debsway-cli.sh` to `~/.local/share/debsway`, symlinked from
`~/.local/bin/debsway` and `/usr/local/bin/debsway` so sway `exec debsway …`
binds resolve regardless of PATH). It mirrors Omarchy's `omarchy <group> <action>` UX:

```
debsway menu | launcher | run | style | theme list|current|set <name>
debsway bg panel|set|cycle|random|reset | power | lock
debsway agent | clip pick|watch|clear | shot full|area|annotate|record|menu
debsway sound panel|up|down|mute | wire panel|status
debsway toggle night|dnd|touchpad|layout | keys [--list]
debsway status media|layout|updates | bar restart|reload
debsway update [--apply] | doctor | setup | help
```

- **Themes** are `themes/<name>/palette.sh` files (hex without `#`); the engine
  renders `themes/_base/tpl/*` across sway/waybar/fuzzel/foot/mako/swayosd/
  wlogout and soft-reloads the session. Add a theme by copying
  `palette.sh` + renaming `C_*` values — no other file changes.
- **Wallpapers** persist: `debsway bg set <file>` writes the
  `~/.local/state/debsway/bg` marker **and** rewrites the `output * bg` line in
  `~/.config/sway/config`, so `$mod+Shift+c` (reload) and `theme set` no longer
  revert to the default. `exec debsway bg apply` in the sway autostart restores
  the marker on every login. `debsway bg reset` returns to the bundled default.
- **`debsway doctor`** checks binaries/configs/renders/services in one pass.
- **`debsway setup`** is the first-run wizard (theme, wallpaper, touchpad, night-light).
- State (active theme, background, toggles) lives in `~/.local/state/debsway/`.

---

## Verification

```bash
./run.sh --verify        # after an install.sh run
bash scripts/verifySetup.sh   # anytime
```

Prints PASS/FAIL/WARN for groups, packages, fonts, Firefox hardening, theme
palettes, debsway config markers and services (`greetd`, TLP, Bluetooth, CUPS,
chrony…). Exits non-zero on any FAIL — so it can gate CI.

After a run there's a full log at
`~/.local/state/deb-sway-thinkpad/last-run.log`, and `scripts/51-backup.sh`
snapshots `~/.config` + fonts + apps + shell dotfiles into a timestamped
tarball before major operations.

---

## Maintenance & troubleshooting

* **Not launched to a graphical session after reboot?** Check greetd's
  status (`doas rc-service greetd status` — `/sbin` isn't on a normal user's
  PATH — or `pgrep -a greetd`) — it needs the seat, and your user must exist
  in `input`/`video`/`render` (script 02). Exactly **one** display manager may
  own the console: the installer enables `greetd` (tuigreet picker), demotes
  SDDM to manual fallback, and moves getty off tty1 (greetd takes `vt = 1`).
  If you re-enable a second DM or re-add a tty1 getty, they fight and none
  wins reliably. At the picker, choose the **DebSway** session (not raw Sway)
  so the login gets a D-Bus session bus for mako/portals/notify.
* **`debsway menu` does nothing?** Update (`git pull` + re-run
  `scripts/21-debsway-cli.sh`), then `$mod+Shift+c` to reload binds. Test with
  `debsway help` and `debsway menu` from foot. Picker errors are visible
  (fuzzel stderr is not hidden); menu entries re-exec through the absolute
  `debsway` path instead of a bare `debsway`, so picks work even when
  sway/waybar launch with a minimal PATH; from a terminal the pick runs
  foreground so subcommand output stays visible (from a keybind it detaches).
* **`debsway wire panel` (Wi-Fi) shows nothing?** Fixed: it used
  `nmcli --json`, which this NetworkManager rejects
  (`Option '--json' is unknown`). It now parses portable
  `nmcli -t -f IN-USE,SIGNAL,SSID dev wifi list` output — no JSON, no python
  dependency.
* **`debsway keys` shows `$left` / `$term`?** Fixed: the cheat-sheet now
  expands `set $var` from your sway config, so `$mod+h` (not `$mod+$left`)
  and the real `$term`/`$menu` commands show. `debsway keys --list` prints
  the same table this README is generated from — if they drift, trust
  `debsway keys --list` (it parses `~/.config/sway/config` live).
* **Volume keys change nothing / no OSD popup?** Two layers: `swayosd-server`
  must be running for the on-screen display (`pgrep -x swayosd-server`; the
  sway autostart launches it, `debsway theme set` restarts it). If the server
  is down, `debsway sound up|down|mute` automatically falls back to `pactl`,
  so volume still moves without the popup. Media keys (`playerctl`) only do
  something while a player (mpv/Firefox/…) is actually playing.
* **Power menu (`debsway power` / wlogout) exits instantly with
  `Invalid JSON Data`?** wlogout 1.2.2's parser only accepts top-level JSON
  **objects** — a pretty-printed `[{…}, {…}]` array is rejected even though it
  is valid JSON. `configs/wlogout/layout` is therefore written as one object
  per line (JSONL-style, no comments — `#` lines break the parser too).
  Keep that shape when editing it. Second rule: the button count must divide
  evenly into the `-b` row width in `debsway power` (5 buttons at `-b 5`):
  wlogout fills the grid column-major and iterates rows×cols, so any
  remainder spawns phantom empty buttons (plus a Gtk-CRITICAL on stderr).
  If you add/remove a button, adjust `-b` to match.
* **Wallpaper reverts after reload?** Fixed: `debsway bg set` now persists to
  both the marker and `sway/config`, and the config autostarts
  `debsway bg apply`. If you edited `sway/config` by hand before updating,
  run `debsway bg set <file>` once to re-persist.
* **Theming**: `configs/` ships the rendered *default* palette; the source of
  truth for colors is `debsway/themes/<name>/palette.sh` + `_base/tpl/`.
  `debsway theme set <name>` re-renders into `~/.config/` and reloads sway —
  hand-edits in `~/.config` survive until the next theme render (marker:
  `~/.local/state/debsway/theme`). To exempt a file you customized (e.g.
  fuzzel's `fuzzel.ini`) from re-rendering, add a `DEBSWAY_KEEP` comment line
  anywhere in it; remove the marker to re-join the theme.
* **Backports**: to pull a newer X from backports, `apt install
  -t excalibur-backports <pkg>` on Devuan (`-t trixie-backports` on Debian) —
  the pin doesn't hold an explicit request back.
* **Firefox locked policy**: `policies.json` is placed system-wide first, then
  the user.js is written into your profile. Both are idempotent.
* **Sway is a WM with a DE shell now** — waybar (menu/workspaces/clock/system
  stats/power), clipboard picker, and themed lockscreen are all wired through
  `debsway`.
* `scripts/assets/xorg-touchpad-fix.sh` is Xorg-only; on Sway/Wayland the libinput
  options already live in `configs/sway/config` — skip it.

---

## Layout

```
run.sh           ordered runner (phases: core/desktop/apps/optional/utils)
install.sh       one-command unattended wrapper
scripts/
  lib/common.sh  shared helpers (DEBSWAY_* envs, ask, pkgs, priv helper)
  ??-*.sh        one step each, numbered = run order; runnable standalone
  verifySetup.sh end-state audit (run.sh --verify)
  skills/deb-sway-thinkpad-SKILL.md   system context for AI agents
configs/         rendered default configs (sway/waybar/fuzzel/foot/mako,
                 swayosd/wlogout/kanshi/gammastep/mpv/xfce4, wallpapers/) — baked
                 into each user's ~/.config
debsway/         the `debsway` CLI: bin/ (router), lib/ (actions, theme
                 engine, doctor, setup), themes/<palette> + _base/tpl/
iso/             live-ISO builder (Devuan live-sdk blend + overlay sync + qemu test)
butterbash/      bundled ButterBash tarball for script 18
assets/          archived material from the source projects
```

---

## Live ISO

Build a bootable Devuan live ISO with the full Sway desktop (autologin as
`live`/`live`) and the **refractainstaller** system installer:

```bash
cd iso && sudo bash build.sh     # needs ~15G free, network, a while
./iso/test-qemu.sh               # smoke-test the result in a VM
sudo dd if=iso/dist/*live.iso of=/dev/sdX bs=4M status=progress && sync
```

- `iso/sync-overlay.sh` stages `scripts/`, `configs/`, `debsway/` and the
  skeleton configs into the blend's `rootfs-overlay` — run it after any
  source change and commit the result (CI enforces this via `--check`).
- The live session ships the toolkit at `/opt/deb-sway-thinkpad` and the
  `debsway` CLI on PATH; `debsway doctor` is the in-session health check.
- Installer: `sudo refractainstaller-gui` (or `-base`) from the live session.