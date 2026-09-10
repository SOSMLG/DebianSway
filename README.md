# deb-sway-thinkpad

A post-install toolkit that turns a fresh **Debian 13 (Trixie)** install into a
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

You run it as your **normal user** (never `sudo bash install.sh`); each script
calls `sudo` itself for the parts that need it.

---

## Quick start

On a fresh Debian 13 (Trixie) install, with the brew role done and internet up:

```bash
# 1. Clone + run
git clone <this-repo> && cd deb-sway-thinkpad
./install.sh
# ~everything, then a verification report; reboot when it finishes

# 2. Reboot — greetd/wlgreet gives you a login screen
#    (systemd: `systemctl reboot`; Devuan/OpenRC: `sudo reboot`)
```

`install.sh` = `run.sh --full --verify`: every step answers **yes**, including
the optional groups (VSCodium, gaming, Vesktop/Telegram, PhotoGIMP, dev tools).
Variants:

| Command | What it does |
|---|---|
| `./install.sh --core` | Core Sway desktop only, skips optional groups |
| `./run.sh --yes` | Everything, but only the default-Y steps (no optional groups) |
| `./run.sh --only 01-backports.sh,usefulApps.sh` | Just those scripts |
| `./run.sh --no-update` | Skip the runner's single `apt-get update` |

Install with `bash -x ./install.sh` to watch every step, if you're curious or
something looks off.

---

## What you get

| Layer | Choice |
|---|---|
| Window manager | **Sway** (Wayland) via **greetd + wlgreet** login. No SDDM/Plasma anywhere |
| Shell layer | **swayosd** OSD, **cliphist** clipboard history, **swappy**/grim/wf-recorder capture, waybar now-playing via **playerctl**, **gammastep** night-light, **kanshi** auto display profiles |
| Theme | **`debsway theme set`** engine (Omarchy-style): 8 one-shot palettes (Catppuccin Mocha/Red default, Mocha/Blue, Frappe, Nord, Dracula, Tokyo Night, Gruvbox, Solarized) compiled into sway/waybar/wofi/foot/mako/swayosd/wlogout/alacritty. Catppuccin Mocha Red cursor pack + red gradient wallpaper |
| Terminal | **Foot** (fast Wayland terminal — `$term`; opencode TUI runs in alacritty) |
| Launcher/menu | **wofi** driving the `debsway` command palette |
| Browser | **Firefox ESR** hardened with Betterfox-derived preferences + a locked `policies.json` |
| Shell | **ButterBash**: saner bash (aliases, history, `eza`/`bat` where present) |
| Input | libinput: tap-to-click on, natural scroll off (baked into `sway/config`) |
| Battery | **TLP** + 80% charge cap via `charge_control_end_threshold` (thinkpad_acpi) |
| Bluetooth | **Blueman** applet (A2DP), not bluedevil |
| GPU | amdgpu + `mesa-vulkan-drivers` + `firmware-amd-graphics` |
| Software | Flatpak/Flathub, CUPS, gufw/ufw, VLC, codecs, GIMP, Timeshift, OpenCode, KeePassXC, btop/eza/bat/zoxide/Neovim |

### Scripts — run order

| # | Script | Default |
|---|---|---|
| 00 | Install the Sway stack + greetd login + Flatpak + configs | Y |
| 01 | Enable backports (trixie-backports) + apt pinning | Y |
| 02 | Add your user to `input`/`video`/`render` groups | Y |
| 03 | Hardware: WiFi/BT/AMD firmware, microcode, fwupd | Y |
| 04 | Bluetooth stack + Blueman | Y |
| 05 | Audio/video codecs + DVD | Y |
| 06 | Firefox ESR + Betterfox hardening | Y |
| 07 | Fonts (Noto, Font Awesome, JetBrainsMono Nerd Font) | Y |
| 08 | ButterBash | Y |
| 09 | fastfetch + config presets | Y |
| 10 | Catppuccin Mocha/Red default theme + cursor (legacy alias of `debsway theme set`) | Y |
| 11 | Desktop essentials (Flatpak, CUPS, firewall, gparted) | Y |
| 12 | Timeshift snapshots | Y |
| 13 | chrony NTP time sync | N |
| 14 | Useful apps (VLC, TLP + battery cap, archives) | Y |
| 15 | OpenCode AI agent + `$mod+a` hotkey (`debsway agent`) | Y |
| 16 | **Sway Shell Upgrade**: OSD, clipboard history, screenshots, media keys, night-light, Foot | Y |
| 17 | **DebSway CLI + theme engine** (`debsway menu/theme/doctor…`) | Y |
| 18 | VSCodium | N (optional) |
| 19 | VSCodium dev config (C++/Python) | N (optional) |
| 20 | Dev extras (btop/eza/bat/zoxide/Neovim/KeePassXC) | N (optional) |
| 21 | GIMP + PhotoGIMP layout | N (optional) |
| 22 | Gaming (Heroic/Steam/Wine) | N (optional) |
| 23 | Vesktop (Discord) / Telegram | N (optional) |
| 24 | System maintenance (apt cleanup) | N (utility) |
| 25 | Config backup (timestamped archive) | N (utility) |
| 26 | Export per-user defaults to `/etc/skel` | N (utility) |

---

## Backports (`scripts/01-backports.sh`)

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

### Keyboard (`$mod = Super`)

| Keys | Action |
|---|---|
| `$mod+Enter` | Terminal (Foot) |
| `$mod+d` / `$mod+Shift+d` | App launcher (wofi drun) / run dialog |
| `$mod+a` | Coding agent (`debsway agent` → OpenCode in alacritty) |
| `$mod+v` | Clipboard history (cliphist picker) |
| `Print` / `$mod+Print` | Screenshot full / area |
| `$mod+Escape` / `$mod+Ctrl+p` | Power menu (wlogout grid) |
| `Super+x` | Lock screen (themed swaylock; `Super+l` is vim-nav focus right) |
| `$mod+Shift+e` | Exit sway (back to greetd) |
| `XF86Audio*` / `XF86Brightness*` | Media keys → playerctl; volume/brightness → pactl/brightnessctl |
| `$mod+Shift+c` | Reload sway config |

---

## The `debsway` CLI

Every desktop-surface action lives behind one command (installed by
`26-debswayCli.sh` to `~/.local/share/debsway`, symlinked from
`~/.local/bin/debsway` and `/usr/local/bin/debsway` so sway `exec debsway …`
binds resolve regardless of PATH). It mirrors Omarchy's `omarchy <group> <action>` UX:

```
debsway menu | launcher | style | theme list|current|set <name>
debsway bg panel|set|cycle|random|reset | power | lock
debsway agent | clip pick|watch|clear | shot full|area|annotate|record|menu
debsway sound panel|up|down|mute | wire panel|status
debsway toggle night|dnd|touchpad|layout | calc | date
debsway status media|layout|updates | bar restart|reload
debsway update [--apply] | doctor | setup | help
```

- **Themes** are `themes/<name>/palette.sh` files (hex without `#`); the engine
  renders `themes/_base/tpl/*` across sway/waybar/wofi/foot/mako/swayosd/
  wlogout/alacritty and soft-reloads the session. Add a theme by copying
  `palette.sh` + renaming `C_*` values — no other file changes.
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
`~/.local/state/deb-sway-thinkpad/last-run.log`, and `scripts/configBackup.sh`
snapshots `~/.config` + fonts + apps + shell dotfiles into a timestamped
tarball before major operations.

---

## Maintenance & troubleshooting

* **Not launched to a graphical session after reboot?** Check greetd's
  status (`systemctl status greetd` on systemd, `rc-service greetd status` on
  OpenRC) — it needs the seat, and your user must exist in
  `input`/`video`/`render` (script 02). Single-GPU laptops are the common case
  and work out of the box; `wlgreet` renders the login list.
* **Theming**: `configs/` ships the rendered *default* palette; the source of
  truth for colors is `debsway/themes/<name>/palette.sh` + `_base/tpl/`.
  `debsway theme set <name>` re-renders into `~/.config/` and reloads sway —
  hand-edits in `~/.config` survive until the next theme render (marker:
  `~/.local/state/debsway/theme`).
* **Backports**: to pull a newer X from backports, `apt install
  -t trixie-backports <pkg>` — the pin doesn't hold an explicit request back.
* **Firefox locked policy**: `policies.json` is placed system-wide first, then
  the user.js is written into your profile. Both are idempotent.
* **Sway is a WM with a DE shell now** — waybar (menu/workspaces/clock/system
  stats/power), clipboard picker, and themed lockscreen are all wired through
  `debsway`.
* `scripts/touchpadTrackpointFix.sh` is Xorg-only; on Sway/Wayland the libinput
  options already live in `configs/sway/config` — skip it.

---

## Layout

```
run.sh           ordered runner (Y/N per script, --only/--full/--verify)
install.sh       one-command unattended wrapper
scripts/
  lib/common.sh  shared helpers (DEBSWAY_* envs, ask, pkgs, sudo wrapper)
  *.sh           one step each; runnable standalone
  25/26          shell upgrade + debsway CLI installers
  skills/deb-sway-thinkpad-SKILL.md   system context for AI agents
configs/         rendered default configs (sway/waybar/wofi/foot/mako,
                 swayosd/wlogout/kanshi/gammastep, wallpapers/) — baked
                 into each user's ~/.config
debsway/         the `debsway` CLI: bin/ (router), lib/ (actions, theme
                 engine, doctor, setup), themes/<palette> + _base/tpl/
butterbash/      bundled ButterBash tarball for script 08
assets/          archived material from the source projects
```