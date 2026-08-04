#!/usr/bin/env bash
# =======================================================
# Timeshift — system snapshot/restore
# -------------------------------------------------------
# Mint's signature safety-net feature: take a snapshot
# before a risky change, roll back with a couple of clicks
# if something breaks. On Debian/Devuan the package depends
# on plain "cron", not systemd — so this works fine on
# Devuan's default sysvinit/runit setup, unlike some
# distros' packaging that leans on systemd timers instead.
#
# This installs the tool and makes sure a cron daemon is
# present, but deliberately does NOT auto-configure a
# snapshot device or schedule — that's a one-time choice
# with real disk-space implications, and Timeshift's own
# setup wizard (first launch) is quick and worth doing
# deliberately rather than silently guessing on your behalf.
# =======================================================
set -uo pipefail

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; NC="\033[0m"

log_info() { echo -e "${CYAN}[*]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

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

if [[ $EUID -eq 0 ]]; then
    log_err "Do not run this as root."
    exit 1
fi

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} Timeshift${NC}"
echo -e "${CYAN}=========================================================${NC}"

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

# cron is normally already present on Devuan/Debian by default, but this
# is defensive in case it was ever removed — Timeshift hard-depends on it.
install_pkgs "cron" cron
install_pkgs "Timeshift" timeshift

if is_installed timeshift; then
    echo -e "${GREEN}Timeshift installed.${NC}"
    log_warn "One-time setup needed: run 'sudo timeshift-launcher' (or find Timeshift in the"
    log_warn "app menu) to choose rsync vs BTRFS mode, where snapshots are stored, and a"
    log_warn "schedule. That choice is left to you rather than guessed automatically."
else
    log_err "Timeshift installation failed."
    exit 1
fi
