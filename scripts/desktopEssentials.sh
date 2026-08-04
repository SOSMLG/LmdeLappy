#!/usr/bin/env bash
# =======================================================
# Desktop Essentials
# -------------------------------------------------------
# The "closest to Mint" completeness pass: a unified software
# manager, plug-and-play printing, a partition tool, and a
# firewall control panel — Cinnamon has no Discover-equivalent
# built in, so this reaches for GNOME Software (Cinnamon's own
# docs recommend it) with a Flatpak backend, gufw as the GTK
# firewall front-end ufw itself lacks, and GParted for
# partitions (same tool KDE Partition Manager wraps under the
# hood, just without the KDE chrome).
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Desktop Essentials"

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Flatpak + Flathub + GNOME Software — a unified software center
#    (apt-installed apps aren't shown, but Flatpak apps get a proper
#    GUI browser/installer, closer to Mint's Software Manager than
#    telling people to memorize apt commands).
# ---------------------------------------------------------------------------
if ask "Set up Flatpak + Flathub + a GUI software installer (gnome-software)?"; then
    install_pkgs "Flatpak + software center" flatpak gnome-software gnome-software-plugin-flatpak

    if command_exists flatpak; then
        if sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
            log_ok "Flathub remote added system-wide."
        else
            log_warn "Could not add the Flathub remote (may already exist)."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 2. Printing — CUPS + broad driver set + network printer auto-discovery
# ---------------------------------------------------------------------------
if ask "Install printing support (CUPS + drivers + network printer auto-discovery)?"; then
    install_pkgs "Printing" cups cups-browsed printer-driver-all system-config-printer

    if is_installed cups; then
        service_enable_now cups
        log_ok "CUPS enabled and started via $(init_system)."
    fi

    if getent group lpadmin >/dev/null 2>&1; then
        if id -nG "$ACTUAL_USER" 2>/dev/null | tr ' ' '\n' | grep -qx lpadmin; then
            log_ok "$ACTUAL_USER already in the lpadmin group."
        elif sudo usermod -aG lpadmin "$ACTUAL_USER"; then
            log_ok "Added $ACTUAL_USER to lpadmin (manage printers without a password prompt each time)."
            log_warn "Log out and back in for this to take effect."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 3. GParted — partition management
# ---------------------------------------------------------------------------
if ask "Install GParted (partition manager)?"; then
    install_pkgs "GParted" gparted
fi

# ---------------------------------------------------------------------------
# 4. Firewall control panel — installed only, NOT enabled/configured.
#    Same philosophy as the KDE toolkit this is modeled on: turning on
#    default-deny-incoming automatically could silently break something
#    you rely on (SSH into this machine, local file sharing), so that's
#    a decision you make yourself once you've confirmed it's safe.
# ---------------------------------------------------------------------------
if ask "Install firewall control panel (gufw, not enabled by default)?"; then
    install_pkgs "Firewall" gufw ufw
    log_warn "Installed only — ufw is NOT enabled yet."
    if ask "Enable it now with ufw's own defaults (deny incoming, allow outgoing)?" "N"; then
        log_warn "This can interrupt anything listening for incoming connections on this machine"
        log_warn "(SSH, local file sharing, etc.) unless you've already allowed it — Ctrl+C now if unsure."
        if sudo ufw default deny incoming && sudo ufw default allow outgoing && sudo ufw --force enable; then
            log_ok "Firewall enabled (deny incoming / allow outgoing)."
            log_info "If you SSH into this machine, run 'sudo ufw allow ssh' now before you disconnect."
        else
            log_err "Something went wrong enabling ufw — check 'sudo ufw status verbose'."
        fi
    fi
fi

echo -e "${GREEN}Desktop essentials step complete.${NC}"
