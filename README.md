# devuan-cinnamon-setup

Post-install polish for a Devuan box where **Cinnamon is already
installed** by the distro's own installer (`task-cinnamon-desktop`). This
does *not* install Cinnamon — it aims a stock Devuan Cinnamon desktop
toward an **LMDE 7 "Gigi"-like feel**: Mint-Y theme and icons, a lighter
package set than a default install, a Timeshift safety net, and a small
cron-based update notifier standing in for Mint's Update Manager — while
staying **lighter than LMDE itself** and native to **Devuan's OpenRC**
init system instead of assuming systemd.

Structure follows the same "ordered runner + flat `scripts/` dir" pattern
as [devuan-kde-setup](.) (this toolkit's sibling for KDE Plasma) and the
DebianSway repo both were modeled after — if you've used either, this
will feel familiar.

```
devuan-cinnamon-setup/
├── run.sh                        # main entry point — run this
├── lib/
│   ├── common.sh                  # shared logging/package/service helpers
│   ├── install-spice.py           # fetches one verified Cinnamon Spice from its official repo
│   ├── dconf-list-add.py          # idempotent "add to a dconf string-array" helper
│   └── panel-applet-add.py        # adds a built-in/spice applet to the panel safely
├── scripts/
│   ├── systemUpdate.sh           # ★ apt update + full-upgrade, run first
│   ├── addUserToGroups.sh        # input/video/render groups
│   ├── cinnamonDebloat.sh        # trim Warpinator/HexChat/GNOME extras, disable Tracker
│   ├── touchpadTrackpointFix.sh  # usbhid mousepoll fix + optional libinput tuning
│   ├── hardwareSupport.sh        # WiFi/BT firmware, CPU microcode, fwupd firmware updates
│   ├── multimediaCodecs.sh       # ffmpeg/GStreamer codecs + DVD playback
│   ├── firefoxHarden.sh          # installs + hardens firefox-esr (Betterfox)
│   ├── policies.json             # firefox enterprise policy used by the above
│   ├── installFonts.sh           # Noto, Font Awesome, JetBrainsMono Nerd Font
│   ├── terminalButterbash.sh     # installs bundled ButterBash
│   ├── fastfetchConfig.sh        # fastfetch + curated config presets
│   ├── usefulApps.sh             # VLC + Nemo archive/thumbnailer completeness
│   ├── mintLook.sh               # ★ Mint-Y theme/icons/cursor/wallpaper — the LMDE look
│   ├── fancyCinnamon.sh          # ★ font, Maximus, Blur, gTile, panel applets, Night Light, etc.
│   ├── nemoActions.sh            # ★ right-click: Compress PDF/Image, Open in VS Code/OpenCode
│   ├── desktopEssentials.sh      # Flatpak+gnome-software, printing, GParted, gufw
│   ├── updateNotifier.sh         # ★ cron-based Mint-Update-style update checker
│   ├── ssdTrim.sh                # ★ weekly SSD TRIM via cron
│   ├── timeshiftSetup.sh         # Timeshift system snapshot/restore tool
│   ├── hotkeys.sh                # ★ Mint/ohmydebn-inspired Cinnamon custom keybindings
│   ├── aiOpencode.sh             # ★ OpenCode AI agent + hotkey + system skill file
│   ├── devToolsExtras.sh         # (optional) btop, eza, bat, zoxide, Neovim+lazy.nvim, KeePassXC
│   ├── themePacks.sh             # (optional) Arc/Papirus/Materia + a theme-picker hotkey
│   ├── installPhotogimp.sh       # (optional) GIMP + PhotoGIMP layout/theme, fetched live from GitHub
│   ├── installVscodium.sh        # (optional) VSCodium via official APT repo
│   ├── vscodiumDevSetup.sh       # (optional) VSCodium C++/Python dev environment
│   ├── gamingSetup.sh            # (optional) Heroic Games Launcher / Steam / Wine
│   └── vesktopTelegram.sh        # (optional) Vesktop (Discord client) / Telegram
├── skills/
│   └── devuan-cinnamon-SKILL.md  # system context file for AI coding agents (OpenCode, Claude Code, ...)
├── butterbash/                   # bundled copy of butterbash-main, used offline
└── README.md
```

Scripts marked ★ are new/Cinnamon-specific, not carried over from the KDE
toolkit. Everything else is the same desktop-agnostic script (fonts,
Firefox hardening, touchpad fix, codecs, Timeshift, PhotoGIMP, VSCodium,
gaming, Vesktop/Telegram) with only cosmetic Cinnamon/Nemo references
swapped in where the original said KDE/Dolphin.

## Why OpenRC gets special treatment

Devuan lets you pick sysvinit, OpenRC, or runit at install time. Most
"Devuan-compatible" scripts floating around just fall back to the generic
`service <name> start` compatibility shim and call it done — which works,
but doesn't actually *use* OpenRC. This toolkit adds a small shared
library, `lib/common.sh`, with a real service abstraction:

```bash
service_enable_now cups   # enable at boot + start now
service_start tlp         # start now only
service_restart cron
```

`init_system` detects what's actually running (`rc-service`+`rc-update`
present and `/etc/runlevels` exists → OpenRC; `systemctl` present and
`/run/systemd/system` exists → systemd; otherwise → sysvinit fallback via
`service`/`update-rc.d`) and every script that touches a service —
CUPS, fwupd, cron, TLP — goes through this instead of duplicating a
systemd-first fallback chain inline. `run.sh` prints which one it
detected up front so you know what's actually being used before anything
runs.

The general-purpose scripts carried over from devuan-kde-setup (fonts,
Firefox, codecs, PhotoGIMP, VSCodium, gaming, Vesktop/Telegram) are left
self-contained with their own small inline helper block, same as
upstream — they don't touch any service, so there was nothing to gain
from converting them, and it keeps the diff against the KDE version
easy to follow if you want to compare the two toolkits side by side.

## Usage

```bash
cd devuan-cinnamon-setup
chmod +x run.sh scripts/*.sh
./run.sh
```

Run it as your **normal user**, not as root and not with `sudo bash
run.sh`. Every script calls `sudo` itself for the specific commands that
need it — this matters because Firefox's profile, your `~/.bashrc`,
Cinnamon's dconf settings, and `~/.local/bin` all need to land in *your*
`$HOME`, not root's.

`run.sh` walks through each script in order and asks `Y/n` (or `y/N`)
before running it. You can also run any script standalone, e.g. just the
theming step:

```bash
bash scripts/mintLook.sh
```

Steps that write Cinnamon/dconf settings (`mintLook.sh`, `hotkeys.sh`,
`themePacks.sh`, the keybinding half of `aiOpencode.sh`) need an **active
local Cinnamon session** to actually apply anything — running them over
SSH before your first graphical login will install the underlying
packages fine, but the "apply to my session" step will just tell you
there's nothing to apply to. Re-run once logged in locally if that
happens.

## What each step does

**systemUpdate.sh** ★ — the essentials video's "update everything first"
step: `apt-get update`, shows how many packages are upgradable, then an
explicit prompt before `apt full-upgrade`. First in the run order for a
reason — everything after it works from a current package index.

**addUserToGroups.sh** — adds you to `input`, `video`, `render` groups.
Needed for some touchpad/trackpoint diagnostics and GPU acceleration.

**cinnamonDebloat.sh** — task-cinnamon-desktop is already leaner than
KDE's task-kde-desktop, so this is a lighter touch than its KDE
counterpart: purges (only what's actually installed, never guesses)
Warpinator (LAN file-sharing with an always-open discovery port), HexChat,
redundant GNOME extras (Weather/Maps/To Do/Contacts/Clocks/Pix), and
optionally simple bundled games. Also disables GNOME Tracker file
indexing (the Baloo-equivalent idle-resource cost Nemo can pull in for
search), with an option to trim LibreOffice to just Writer+Calc and to
disable Cinnamon's window/menu animations for older hardware. Nothing
here touches Cinnamon itself, Nemo, Xed, or any core app.

**touchpadTrackpointFix.sh** — applies the `usbhid mousepoll=2` fix,
backing up any existing file first, rebuilding initramfs, and attempting
a live `modprobe -r usbhid && modprobe usbhid` so you don't have to
reboot immediately. Optionally also drops a libinput Xorg conf snippet
(tap-to-click, natural-scroll off, trackpoint acceleration).

**hardwareSupport.sh** — WiFi/Bluetooth firmware for Intel/Realtek/
Atheros/Broadcom chips, auto-detected CPU microcode, and fwupd for
BIOS/UEFI + peripheral firmware updates via LVFS (with `gnome-firmware`
as an optional GUI front-end, since Cinnamon has no Discover-equivalent
built in).

**multimediaCodecs.sh** — ffmpeg + the full GStreamer plugin set, plus
`libdvd-pkg` for DVD playback, run under a hard 5-minute timeout so the
debconf-driven `libdvdcss` build can never hang the install.

**firefoxHarden.sh** — installs `firefox-esr` if missing, pulls the
pinned [Betterfox](https://github.com/yokoffing/Betterfox) `user.js`,
installs `policies.json` (disables telemetry/Pocket/sponsored content,
force-installs uBlock Origin), and installs a `~/.local/bin` wrapper so
the hardened profile re-applies on every launch.

**installFonts.sh** — Noto (Latin + Arabic + Emoji), Font Awesome, and
JetBrainsMono Nerd Font (latest GitHub release, with a pinned fallback
URL), plus a fontconfig preference file.

**terminalButterbash.sh** — installs the bundled `butterbash/` directory
(no network dependency on the original repo): a saner bash prompt, fzf
integration, and quality-of-life aliases/functions.

**fastfetchConfig.sh** — installs fastfetch + curated config presets.

**usefulApps.sh** — VLC (set as the default player for common media
types), archive support for Nemo (`file-roller` + `nemo-fileroller`,
7z/rar), and Nemo thumbnailers for video/RAW/webp previews. Optional
qBittorrent and TLP (power management — enabled through
`service_enable_now`, so it comes up correctly under OpenRC).

**mintLook.sh** ★ — the script that actually makes this look like LMDE:

- Mint-Y and Mint-X **icon themes** straight from Debian's own repo
  (packaged and maintained by the Debian Cinnamon Team — no extra APT
  source needed).
- The Mint-Y **GTK/Cinnamon theme** itself, built from
  [linuxmint/mint-themes](https://github.com/linuxmint/mint-themes)
  source the same way `installPhotogimp.sh` builds PhotoGIMP: latest
  release tag via the GitHub API, pinned fallback tag if that's
  unavailable, verified output layout before anything is copied into
  `~/.themes`.
- An optional Bibata **cursor theme**, only if it's actually available
  in your configured repos (checked, never assumed).
- A **wallpaper** generated locally with ImageMagick in Mint-Y's
  charcoal-and-green palette — no download, so this step never depends
  on network availability.
- Applies all of the above to your current Cinnamon session via
  `gsettings`/dconf.

Deliberately does **not** add Linux Mint's own APT repository to your
system — that needs GPG key management and a suite/codename match to
your exact Debian base, and would leave a permanent third-party signed
source behind. Building from source (same pattern as PhotoGIMP) avoids
all of that.

**fancyCinnamon.sh** ★ — the theming/productivity pass pulled from two
Linux Mint YouTube walkthroughs (see **Video credits** below). Two kinds
of steps:

- *Built-in Cinnamon features, toggled via dconf only* — the Inter font
  (fetched straight from
  [google/fonts](https://github.com/google/fonts) on GitHub, applied as
  the desktop/document/window-title font), Workspace Switcher + Window
  List panel applets, Alt-Tab set to the Coverflow style, Night Light
  (built into Cinnamon 6.4+, which is what Debian trixie ships), and a
  `Super+L` lock-screen keybinding.
- *Real Cinnamon Spices*, fetched directly from the official
  `linuxmint/cinnamon-spices-{extensions,applets}` GitHub repos via
  `lib/install-spice.py` (only that spice's files, not the whole
  multi-hundred-extension repo) — every UUID below was verified by hand
  against those repos rather than guessed:
  - `cinnamon-maximus@fmete` — hides the titlebar on maximized windows
    (hold Alt and nudge the mouse to get it back temporarily).
  - `BlurCinnamon@klangman` — blurs the panel/menu to match your
    wallpaper.
  - `gTile@shuairan` — window-tiling grid, `Super+G`.
  - `CinnamonMagicLamp@klangman` and `CinnamonBurnMyWindows@klangman`
    *(off by default)* — genie-style minimize and animated open/close
    window effects.
  - `color-picker@fmete` *(off by default)* — screen color picker
    applet; has a history of dependency issues (`python3-numpy`,
    `python3-xlib`), hence opt-in.

Left out on purpose: Desktop Cube and Flipper (real spices, but their
exact current UUIDs weren't confidently verified, and 3D compositor
effects are the most failure-prone category here — install them
yourself from Cinnamon Settings > Extensions > Download if you want
them), and browsing gnome-look.org for a specific community theme —
there's no stable way to script "the exact pack shown in a video," and
mintLook.sh already covers the actual Mint-Y look this toolkit targets.

**nemoActions.sh** ★ — self-written right-click context-menu actions
rather than downloaded Cinnamon Spices Actions, so the logic is a
2-page shell script you can read, not a third-party action's exact
current behavior: **Compress PDF** (Ghostscript, `/ebook` preset),
**Compress Image** (ImageMagick, quality 85), **Open in VS Code** (only
added if `code`/`codium` is actually on PATH), and **Open in OpenCode**
(opens a terminal in that folder running OpenCode — ties directly into
`aiOpencode.sh`). Each is a small wrapper script in `~/.local/bin` plus
a `.nemo_action` file; Nemo picks up new actions live in most versions,
`nemo -q` forces a refresh if one doesn't appear.

**desktopEssentials.sh** — Flatpak + Flathub + `gnome-software` as a
unified software center (Cinnamon has no Discover-equivalent, so this is
the closest "click to install stuff" experience without hand-rolling
one), CUPS printing with driver auto-discovery, GParted, and `gufw` as a
firewall control panel. Installing `gufw` and actually enabling the
firewall are two separate prompts — enabling defaults to **off** and
comes with a clear warning about SSH/local file sharing, same "don't
silently change your machine's behavior" philosophy as the rest of this
toolkit, but the option to enable it with ufw's own sane defaults (deny
incoming, allow outgoing — the essentials video's firewall step) is
right there if you want it in one step instead of digging through the
GUI.

**updateNotifier.sh** ★ — real `mintupdate` isn't packaged for Devuan (it
pulls in Mint-specific tooling not present outside Mint's own repos), so
this is a small, transparent stand-in: a **cron job** (works identically
under OpenRC, sysvinit, or systemd, since cron itself is init-agnostic)
that checks for upgradable packages twice a day and sends a desktop
notification via `notify-send` if there are any. No background daemon,
no systemd timer unit — just cron, a ~15-line checker script in
`~/.local/bin`, and Synaptic installed as the point-and-click way to
actually apply what it finds. It only checks and notifies — it never
applies updates on its own.

**ssdTrim.sh** ★ — the essentials video's "enable TRIM" step. Debian
normally does this with a systemd timer (`fstrim.timer`) that doesn't
exist under OpenRC/sysvinit; this is the same idea (`fstrim -av` on a
schedule) via a cron job instead — safe to install even without an SSD,
since `fstrim` silently skips any filesystem that doesn't support it.

**timeshiftSetup.sh** — installs Timeshift, Mint's signature "snapshot
before a risky change, roll back if it breaks" safety net. Depends on
plain `cron`, not systemd, so it works the same under OpenRC. Doesn't
auto-configure a snapshot device or schedule — that's a one-time choice
with real disk-space implications, left to Timeshift's own setup wizard.

**hotkeys.sh** ★ — adds a small set of Cinnamon custom keybindings for
things it has no built-in shortcut for: `Super+Return` and `Ctrl+Alt+T`
for a terminal, `Super+F` for Nemo, `Ctrl+Super+E` for Xed, `Ctrl+Shift+
Escape` for a quick htop. Cinnamon's own defaults (Super for the menu,
Alt+Tab, screenshot keys, window tiling via `Super+arrows`) are left
untouched. **No app-launcher hotkey/Rofi here on purpose** — Cinnamon's
built-in Menu applet already covers app launching, so this toolkit skips
adding an extra launcher dependency to stay lighter. Merges into your
existing custom-keybindings list via a small Python helper rather than
overwriting it, so it's safe to re-run or combine with your own bindings.

**aiOpencode.sh** ★ — installs [OpenCode](https://opencode.ai), an
open-source terminal AI coding agent that works with Claude, GPT, Gemini,
or other providers (bring your own key, or use its free tier). This is
the one piece taken essentially as-is from
[ohmydebn](https://github.com/dougburks/ohmydebn) (MIT licensed) rather
than reimplemented — same tool, same "one hotkey, installs-then-runs"
idea, adapted to launch in whatever terminal `x-terminal-emulator` points
to instead of assuming Alacritty. Lets you choose the official curl
installer or npm (if you'd rather not pipe curl to bash sight-unseen).
Also drops a system "skill" file (`skills/devuan-cinnamon-SKILL.md`) into
`~/AGENTS.md` and `~/.config/opencode/AGENTS.md` so OpenCode (or Claude
Code, if you use both) knows up front that this is a Devuan/OpenRC/
Cinnamon box — no systemd, no `systemctl`, use `rc-service`/`rc-update`
instead — same concept as ohmydebn's own "skill that all these AI tools
can use to understand the platform."

**devToolsExtras.sh** *(optional, defaults to skip)* — a small curated
pull from ohmydebn's ingredient list, stopping short of its heavier
stack (no Docker/VMs/Zsh+Starship as a whole new shell, no Rofi, no
Omarchy theming — those didn't fit "lighter and easier" or don't map
onto Cinnamon cleanly): btop, eza + bat (with the Debian `batcat` binary
symlinked to `bat` so ButterBash's aliases just work), zoxide (activates
ButterBash's existing `zoxide.bash` integration — it was already wired
up, just needed the binary), and KeePassXC.

For Neovim, this deliberately does **not** install LazyVim or
kickstart.nvim — LazyVim currently requires Neovim >= 0.11.2 and
kickstart.nvim >= 0.12, but Debian trixie packages Neovim 0.10.4, so
both fail to bootstrap out of the box on this toolkit's target system.
Instead it lays down a small, hand-written `init.lua` that bootstraps
just [lazy.nvim](https://github.com/folke/lazy.nvim) (the plugin
manager underneath LazyVim, needs only Neovim >= 0.8.0) with a
hand-picked, version-safe plugin set: Treesitter, Telescope,
nvim-lspconfig, gitsigns, lualine, and a colorscheme. Genuinely useful,
nothing that requires bleeding-edge Neovim. Skipped entirely if you
already have an `~/.config/nvim`, same as `vscodiumDevSetup.sh`'s
starter-project behavior.

**themePacks.sh** *(optional, defaults to skip)* — Arc, Papirus, and
Materia theme/icon packs from Debian's own repos, plus a small
`zenity`-based theme-picker script bound to `Ctrl+Super+T` (same key
ohmydebn uses for its own theme picker) that applies GTK theme, Cinnamon
shell theme, and window-manager theme together so they never end up
mismatched.

**installPhotogimp.sh**, **installVscodium.sh**, **vscodiumDevSetup.sh**,
**gamingSetup.sh**, **vesktopTelegram.sh** — unchanged from
devuan-kde-setup; none of them touch anything KDE- or init-system-
specific. See the KDE toolkit's README for the full writeup of each —
the short version: PhotoGIMP built from source with version-matching
checks, VSCodium via its official APT repo, a C++/Python dev environment
with clangd+CodeLLDB and basedpyright+Ruff (since `ms-vscode.cpptools`
and Pylance both refuse to run on VSCodium), Steam via Valve's own `.deb`
+ Heroic's latest GitHub release + Wine, and Vesktop/Telegram via their
own latest releases.

## Video credits

`systemUpdate.sh`, `fancyCinnamon.sh`, `nemoActions.sh`, and `ssdTrim.sh`
(plus the firewall-enable option in `desktopEssentials.sh`) were built
from watching two Linux Mint YouTube walkthroughs — one on appearance
tweaks (custom fonts, GTK/icon/cursor themes, panel blur, hiding the
titlebar on maximize, Nemo Actions, window tiling) and one on
post-install essentials (updates, codecs, firewall, Night Light, TLP,
SSD TRIM, hot corners, touchpad gestures, lock-screen shortcut, search
settings). Not everything demonstrated made it in — anything that meant
manually browsing gnome-look.org for one specific community theme, or
that this toolkit couldn't verify against a stable source (exact
extension UUIDs, exact package names), was either left out, swapped for
a verified equivalent, or pointed to as a manual step in the relevant
script's own output instead of being silently guessed at.

## Notes / things worth knowing before you run it

- Every apt action first checks what's *actually installed* — nothing is
  blindly force-purged or force-installed, so re-running any script is
  safe and idempotent.
- `cinnamonDebloat.sh` never removes Cinnamon itself, Nemo, or any core
  app — only the extras listed above, each behind its own y/N prompt.
- Init system is auto-detected (OpenRC preferred, systemd or sysvinit
  both handled correctly) rather than assumed — `run.sh` prints which one
  it found before anything runs.
- Nothing in this toolkit auto-enables a firewall deny rule or auto-adds
  a third-party APT repository without a separate, explicit prompt —
  install-and-get-out-of-the-way is the default philosophy throughout,
  same as the KDE toolkit this is modeled on, with the firewall-enable
  option in `desktopEssentials.sh` as the one opt-in exception.
- Reboot (or at least log out/in) after a full run — group membership,
  the mousepoll fix, newly installed firmware/microcode, theme changes,
  and Cinnamon keybindings all benefit from a fresh session.

## Attribution

- Runner/script structure pattern: DebianSway, via this author's own
  [devuan-kde-setup](.).
- AI tooling (OpenCode + a system skill file), the curated dev-tools
  extras, and the theme-picker concept: adapted from
  [OhMyDebn](https://github.com/dougburks/ohmydebn) by Doug Burks (MIT
  licensed) — a Debian + systemd + Cinnamon "power user" desktop with AI,
  containers, and virtualization built in. This toolkit borrows the parts
  that fit a lighter, OpenRC-native scope and leaves the rest (Docker,
  VMs, Omarchy theming, Alacritty+Zsh+Starship as a whole new shell) out.
  See [ohmydebn.org](https://ohmydebn.org) for the full original project.
- Mint-Y/Mint-X icons and the mint-themes source: [Linux
  Mint](https://linuxmint.com/) / [linuxmint on
  GitHub](https://github.com/linuxmint), packaged for Debian by the
  Debian Cinnamon Team.
- Cinnamon Maximus, Blur Cinnamon, gTile, Magic Lamp Effect, Burn My
  Windows, and the Color Picker applet: fetched from the official
  [linuxmint/cinnamon-spices-extensions](https://github.com/linuxmint/cinnamon-spices-extensions)
  and
  [linuxmint/cinnamon-spices-applets](https://github.com/linuxmint/cinnamon-spices-applets)
  repos — each written and maintained by its own author (klangman,
  fmete, shuairan credited in-repo), distributed through Linux Mint's
  own Cinnamon Spices platform.
- Inter font: [The Inter Project](https://github.com/rsms/inter),
  fetched from Google's [google/fonts](https://github.com/google/fonts)
  mirror (OFL-1.1 licensed).
- lazy.nvim: [folke/lazy.nvim](https://github.com/folke/lazy.nvim),
  bootstrapped by devToolsExtras.sh's starter `init.lua`.
- ButterBash: bundled from its own upstream repo, see
  `butterbash/README.md` and `butterbash/LICENSE` for its own attribution
  and license.
