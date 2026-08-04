# System skill: Devuan Cinnamon Setup

You are running on a Devuan GNU/Linux system that has been set up with the
**devuan-cinnamon-setup** toolkit — an LMDE 7 "Gigi"-style Cinnamon desktop
running on Devuan instead of Debian, with OpenRC as the init system instead
of systemd. Keep the following in mind for any system-level help you give:

## Init system: OpenRC (not systemd)

- This box does **not** run systemd. Do not suggest `systemctl`,
  `journalctl`, `systemd-analyze`, or unit files as solutions.
- Use `rc-service <name> start|stop|restart|status` to control services.
- Use `rc-update add <name> default` / `rc-update del <name> default` to
  enable/disable services at boot.
- Logs generally live under `/var/log/` (syslog via a traditional logger
  like rsyslog or syslog-ng), not in a systemd journal.
- Some Devuan boxes run plain sysvinit instead of OpenRC — if `rc-service`
  isn't found, fall back to `service <name> start` and `update-rc.d
  <name> defaults`, which work under both sysvinit and OpenRC.
- Cron (not systemd timers) is used for anything scheduled — see
  `crontab -l` for the current user's jobs.

## Package management

- Standard Debian-family `apt` / `apt-get` / `dpkg`. Devuan tracks Debian's
  package base closely, so most Debian documentation and packages apply
  directly.
- Check whether a package is installed with:
  `dpkg-query -W -f='${Status}' <pkg> | grep -q "install ok installed"`
  rather than assuming.

## Desktop environment: Cinnamon

- File manager is **Nemo**, not Nautilus/Dolphin.
- Default text editor is **Xed** (Cinnamon's GEdit-alike).
- Desktop settings live in dconf/gsettings under schemas like
  `org.cinnamon.*`, `org.cinnamon.desktop.*`, and (for compatibility)
  some `org.gnome.desktop.*` keys. Changing them requires an active
  graphical session as the target user — `gsettings set <schema> <key>
  <value>` run as root or without `DISPLAY`/`DBUS_SESSION_BUS_ADDRESS`
  set will silently fail or write nowhere useful.
- The system aims for a Linux Mint (LMDE)-like look and feel: Mint-Y
  theme/icons where installed, a lighter package set than a stock KDE or
  GNOME install, Timeshift for snapshots, and a lightweight cron-based
  update notifier instead of a heavyweight background update daemon.

## Toolkit layout (if asked about "this setup" or shown this repo)

```
devuan-cinnamon-setup/
├── run.sh              # ordered interactive installer — run this first
├── lib/common.sh        # shared logging/package/service helpers
├── scripts/*.sh         # one script per feature area, each independently runnable
└── skills/               # this file
```

Every script in `scripts/` is safe to re-run (checks what's already
installed/applied before acting) and only prompts for things it's about to
change — nothing runs silently or destructively. When helping debug or
extend this system, follow the same pattern: check `is_installed`,
`command_exists`, or the current dconf value before changing anything, and
prefer additive/idempotent changes.

## Attribution

This toolkit's structure follows the "ordered runner + flat scripts/ dir"
pattern used by DebianSway and this author's own devuan-kde-setup. The AI
tooling pattern (OpenCode + a system skill file) and the idea of curating
a small set of theme/dev-tool extras were inspired by
[OhMyDebn](https://github.com/dougburks/ohmydebn) (MIT licensed), adapted
here for Cinnamon-on-Devuan with OpenRC instead of OhMyDebn's Debian +
systemd base.
