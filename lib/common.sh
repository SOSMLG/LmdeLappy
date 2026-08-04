#!/usr/bin/env bash
# =======================================================
# lib/common.sh — shared helpers for every script in this toolkit
# -------------------------------------------------------
# Source this near the top of a script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/../lib/common.sh"
#
# Provides:
#   - colored log_info/log_ok/log_warn/log_err
#   - ask "question" [Y|N]                  -> y/n prompt with default
#   - is_installed <pkg>                    -> dpkg check
#   - install_pkgs "label" pkg1 pkg2 ...     -> only installs what's missing
#   - purge_if_installed "label" pkg1 ...    -> only purges what's present
#   - init_system                           -> prints: openrc | systemd | sysvinit
#   - service_enable_now <svc>              -> enable+start on whatever init runs
#   - service_start <svc>                   -> start only, no enable-at-boot
#   - require_not_root
#   - actual_user / run_as_user <cmd...>    -> for when the script runs via sudo
# =======================================================

# Don't re-source
if [ -n "${DCS_COMMON_LOADED:-}" ]; then return 0 2>/dev/null || exit 0; fi
DCS_COMMON_LOADED=1

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; BLUE="\033[1;34m"; NC="\033[0m"

log_info() { echo -e "${CYAN}[*]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }
log_head() {
    echo -e "${CYAN}=========================================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}=========================================================${NC}"
}

ask() {
    local prompt="$1" default="${2:-Y}" reply
    local hint="(Y/n)"
    [ "$default" = "N" ] && hint="(y/N)"
    read -rp "$(echo -e "${YELLOW}${prompt} ${hint}: ${NC}")" reply
    reply=${reply:-$default}
    [[ "$reply" =~ ^[Yy]$ ]]
}

require_not_root() {
    if [[ $EUID -eq 0 ]] && [ -z "${SUDO_USER:-}" ]; then
        log_err "Do not run this as root / sudo bash <script>.sh — run as your normal user."
        log_err "This script calls sudo itself for the parts that need it."
        exit 1
    fi
}

is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

install_pkgs() {
    local label="$1"; shift
    local to_install=()
    local pkg
    for pkg in "$@"; do
        is_installed "$pkg" || to_install+=("$pkg")
    done
    if [ "${#to_install[@]}" -eq 0 ]; then
        log_ok "$label already installed."
        return 0
    fi
    log_info "$label: installing ${to_install[*]}"
    if sudo apt-get install -y "${to_install[@]}"; then
        log_ok "$label installed."
    else
        log_warn "$label: some packages failed to install (continuing)."
        return 1
    fi
}

purge_if_installed() {
    local label="$1"; shift
    local to_purge=()
    local pkg
    for pkg in "$@"; do
        is_installed "$pkg" && to_purge+=("$pkg")
    done
    if [ "${#to_purge[@]}" -eq 0 ]; then
        log_info "$label: nothing installed, skipping."
        return 0
    fi
    log_info "$label: purging ${to_purge[*]}"
    if sudo apt-get purge -y "${to_purge[@]}"; then
        log_ok "$label removed."
    else
        log_warn "$label: some packages failed to purge (continuing)."
    fi
}

# ---------------------------------------------------------------------------
# Init system detection & service abstraction.
#
# Devuan can boot under sysvinit, OpenRC, or runit — this toolkit is written
# for the OpenRC variant, but detects at runtime rather than assuming, so it
# doesn't break on a sysvinit or (Debian) systemd box someone runs it on.
#
# Priority: OpenRC native (rc-service/rc-update) > systemd > sysvinit fallback
# (service + update-rc.d — Devuan's sysvinit and OpenRC both understand this).
# ---------------------------------------------------------------------------
init_system() {
    if command_exists rc-service && command_exists rc-update && [ -d /etc/runlevels ]; then
        echo "openrc"
    elif command_exists systemctl && [ -d /run/systemd/system ]; then
        echo "systemd"
    else
        echo "sysvinit"
    fi
}

# Enable a service at boot AND start it now.
service_enable_now() {
    local svc="$1"
    case "$(init_system)" in
        openrc)
            sudo rc-update add "$svc" default >/dev/null 2>&1 || true
            sudo rc-service "$svc" start >/dev/null 2>&1 || true
            ;;
        systemd)
            sudo systemctl enable --now "$svc" >/dev/null 2>&1 || true
            ;;
        sysvinit)
            sudo update-rc.d "$svc" defaults >/dev/null 2>&1 || true
            sudo service "$svc" start >/dev/null 2>&1 || true
            ;;
    esac
}

# Start a service now without touching its boot-time enablement.
service_start() {
    local svc="$1"
    case "$(init_system)" in
        openrc)   sudo rc-service "$svc" start >/dev/null 2>&1 || true ;;
        systemd)  sudo systemctl start "$svc" >/dev/null 2>&1 || true ;;
        sysvinit) sudo service "$svc" start >/dev/null 2>&1 || true ;;
    esac
}

service_restart() {
    local svc="$1"
    case "$(init_system)" in
        openrc)   sudo rc-service "$svc" restart >/dev/null 2>&1 || true ;;
        systemd)  sudo systemctl restart "$svc" >/dev/null 2>&1 || true ;;
        sysvinit) sudo service "$svc" restart >/dev/null 2>&1 || true ;;
    esac
}

ACTUAL_USER="${SUDO_USER:-$USER}"
run_as_user() {
    if [ "$(id -un)" = "$ACTUAL_USER" ]; then
        "$@"
    else
        sudo -u "$ACTUAL_USER" "$@"
    fi
}

# gsettings/dconf writes need a session bus. Cinnamon settings live in
# dconf, which works fine without systemd (dconf is a plain file-backed
# store + a dbus service — dbus itself runs happily under OpenRC), but we
# still need to run the write AS the desktop user, not root.
user_gsettings() {
    run_as_user dbus-launch --exit-with-session gsettings "$@" 2>/dev/null \
        || run_as_user gsettings "$@" 2>/dev/null \
        || return 1
}
