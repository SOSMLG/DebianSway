# DebianSway - project instructions

Sway (Wayland) desktop toolkit for Devuan 6 (Excalibur) and Debian 13
(Trixie), tuned for ThinkPad-class AMD hardware. No systemd: Devuan uses
OpenRC or sysvinit.

## Entry points

- `run.sh` discovers `scripts/??-*.sh`, groups them by phase, and reads
  `# DEBSWAY_DESC:` and `# DEBSWAY_DEFAULT:` headers.
- `install.sh` is the unattended wrapper.
- `scripts/verifySetup.sh` is the read-only end-state audit. `run.sh --verify`
  runs it after a setup pass.
- `debsway/` holds the CLI and palette engine.

## Conventions

- Run as a normal user. Privilege escalation lives in `scripts/lib/common.sh`:
  prefer doas, fall back to sudo, honor `DEBSWAY_PRIV=doas|sudo`. Do not write
  bare sudo or doas in new steps.
- Use `install_pkgs` for apt work and check installed state before acting.
  Never write systemd units or service calls.
- Keep configs in `configs/` portable; no hard-coded usernames.
- The default desktop identity is Graphite Amber; keep theme values aligned
  with `debsway/themes/graphite-amber/palette.sh`.
- Back up before destructive writes. Re-running any step must be safe.
## Verification

- `bash -n` on changed shell files.
- `bash scripts/verifySetup.sh` on a target system.
- `bash run.sh --list` after adding or renaming a step.
