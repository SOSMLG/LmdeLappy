#!/usr/bin/env bash
# =======================================================
# Cinnamon Debloat (Devuan/Debian)
# -------------------------------------------------------
# task-cinnamon-desktop is already much leaner than KDE's task-kde-desktop,
# so this is a lighter touch than kdeDebloat.sh's KDE equivalent — mostly
# trimming a handful of extras that get pulled in (Warpinator's open
# network-discovery port, HexChat, a duplicate image viewer, GNOME's
# Tracker file indexer) rather than wholesale app-suite removal.
#
# Nothing here is destructive to your files — only installed .deb packages
# and a couple of per-user Cinnamon (dconf) settings. Every category is
# its own y/N prompt, and nothing is purged unless it's actually installed.
# =======================================================

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

log_head "Cinnamon Debloat"

if ! command_exists apt-get; then
    log_err "apt-get not found — this script needs a Debian/Devuan APT system."
    exit 1
fi

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Warpinator — LAN file-sharing via an always-listening discovery port.
#    Handy on a home network, unnecessary attack surface on a laptop that
#    roams onto untrusted WiFi. Your call.
# ---------------------------------------------------------------------------
if ask "Remove Warpinator (LAN file-sharing tool with an always-open discovery port)?"; then
    purge_if_installed "Warpinator" warpinator
fi

# ---------------------------------------------------------------------------
# 2. HexChat — IRC client almost nobody using a Mint-style desktop touches.
# ---------------------------------------------------------------------------
if ask "Remove HexChat (IRC client)?"; then
    purge_if_installed "HexChat" hexchat hexchat-common hexchat-python
fi

# ---------------------------------------------------------------------------
# 3. GNOME extras sometimes pulled in as Recommends (weather/maps/todo/
#    contacts/clocks apps that duplicate what a browser or phone already
#    does for most people, plus Pix, a second image viewer alongside Xviewer).
# ---------------------------------------------------------------------------
if ask "Remove redundant GNOME extras (Weather, Maps, To Do, Contacts, Clocks, Pix)?"; then
    purge_if_installed "GNOME extras" \
        gnome-weather gnome-maps gnome-todo gnome-contacts gnome-clocks pix
fi

# ---------------------------------------------------------------------------
# 4. Simple games sometimes pulled in as Recommends alongside the desktop
#    task (aisleriot/mines/sudoku). Keep if you actually play them.
# ---------------------------------------------------------------------------
if ask "Remove bundled simple games (aisleriot, gnome-mines, gnome-sudoku)?" "N"; then
    purge_if_installed "Simple games" aisleriot gnome-mines gnome-sudoku
fi

# ---------------------------------------------------------------------------
# 5. Cleanup orphaned dependencies
# ---------------------------------------------------------------------------
if ask "Run apt autoremove + clean to drop now-orphaned dependencies?"; then
    log_info "Running apt-get autoremove --purge..."
    sudo apt-get autoremove --purge -y || log_warn "autoremove reported issues (non-fatal)."
    log_info "Running apt-get clean..."
    sudo apt-get clean || true
    log_ok "Cleanup done."
fi

# ---------------------------------------------------------------------------
# 6. Disable Tracker file indexing (GNOME's Baloo-equivalent). Nemo pulls
#    it in on modern Cinnamon builds for filename/content search; it's a
#    real idle-CPU/disk cost on a "minimal" install, same as Baloo on KDE.
#    This disables + masks it rather than removing the packages outright,
#    since other apps (gvfs, file-roller) can share the same libtracker
#    dependency and a hard purge risks apt wanting to take them with it.
# ---------------------------------------------------------------------------
if ask "Disable Tracker file indexing (recommended for a lean/minimal feel)?"; then
    if command_exists tracker3; then
        run_as_user tracker3 reset --hard >/dev/null 2>&1 || true
    fi
    # Belt-and-suspenders: disable crawling/indexing via dconf regardless of
    # whether the tracker3 CLI is present, and mask the dbus-activatable
    # miner services so nothing silently re-launches them. This works the
    # same under OpenRC as under systemd because Tracker is a session/dbus
    # service, not an init-managed one — it isn't started by rc-service or
    # systemctl either way, only dbus-activated on first file-search use.
    if user_gsettings set org.freedesktop.Tracker3.Miner.Files crawling-interval -2 2>/dev/null; then
        log_ok "Tracker crawling disabled (crawling-interval=-2)."
    else
        log_warn "Could not write Tracker dconf settings (Tracker may not be installed — that's fine)."
    fi
    mkdir -p "$HOME/.config/systemd/user" 2>/dev/null || true
    for svc in tracker-miner-fs-3 tracker-extract-3 tracker-writeback-3 tracker-xdg-portal-3; do
        run_as_user ln -sf /dev/null "$HOME/.config/systemd/user/${svc}.service" 2>/dev/null || true
    done
    log_ok "Tracker indexing disabled."
fi

# ---------------------------------------------------------------------------
# 7. Trim LibreOffice down to Writer + Calc (optional — skips if you use
#    Impress/Draw/Base, off by default since removing apps someone relies
#    on is a bigger deal than the KDE animation tweak this mirrors).
# ---------------------------------------------------------------------------
if ask "Trim LibreOffice to just Writer + Calc (removes Impress, Draw, Base, Math)?" "N"; then
    purge_if_installed "LibreOffice extras" \
        libreoffice-impress libreoffice-draw libreoffice-base libreoffice-math
fi

# ---------------------------------------------------------------------------
# 8. Cinnamon desktop effects — window animations, workspace OSD, menu
#    fades. Cheap on modern hardware, worth trimming on something old
#    enough that "lighter" actually matters. Off by default; opt in.
# ---------------------------------------------------------------------------
if ask "Disable Cinnamon desktop effects (window/menu animations) for max snappiness on older hardware?" "N"; then
    if user_gsettings set org.cinnamon desktop-effects false; then
        log_ok "Cinnamon desktop effects disabled."
    else
        log_warn "Could not write the Cinnamon effects setting — set it manually in Cinnamon Settings > Effects."
    fi
fi

echo -e "${GREEN}Cinnamon debloat complete.${NC}"
log_warn "Log out and back in (or run 'cinnamon --replace &' disown) for the Tracker/effects changes to fully apply."
