#!/usr/bin/env bash
# =======================================================
# Hardware Support — firmware, microcode, firmware updates
# -------------------------------------------------------
# Covers the "why doesn't my WiFi/Bluetooth work out of the
# box" class of issues, which is almost always a missing
# non-free firmware blob rather than a real driver problem.
# Also installs CPU microcode (auto-detected Intel vs AMD)
# and fwupd for BIOS/UEFI + peripheral firmware updates via
# LVFS, surfaced through Discover so it's not a separate app.
#
# All of this is inert on hardware it doesn't apply to —
# firmware blobs sit unused in /lib/firmware until matching
# hardware is present, so installing the common set doesn't
# conflict with staying minimal.
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

ask() {
    local prompt="$1" default="${2:-Y}" reply
    local hint="(Y/n)"
    [ "$default" = "N" ] && hint="(y/N)"
    read -rp "$(echo -e "${YELLOW}${prompt} ${hint}: ${NC}")" reply
    reply=${reply:-$default}
    [[ "$reply" =~ ^[Yy]$ ]]
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
    fi
}

if [[ $EUID -eq 0 ]]; then
    log_err "Do not run this as root."
    exit 1
fi

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} Hardware Support${NC}"
echo -e "${CYAN}=========================================================${NC}"

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Common WiFi/Bluetooth firmware
# ---------------------------------------------------------------------------
if ask "Install common WiFi/Bluetooth firmware (Intel/Realtek/Atheros/Broadcom)?"; then
    install_pkgs "WiFi/Bluetooth firmware" \
        firmware-iwlwifi firmware-realtek firmware-atheros \
        firmware-brcm80211 firmware-misc-nonfree firmware-linux
fi

# ---------------------------------------------------------------------------
# 2. CPU microcode — auto-detected, never both
# ---------------------------------------------------------------------------
if ask "Install CPU microcode updates (auto-detects Intel/AMD)?"; then
    VENDOR="$(grep -m1 -oE 'GenuineIntel|AuthenticAMD' /proc/cpuinfo || true)"
    case "$VENDOR" in
        GenuineIntel)
            log_info "Detected Intel CPU."
            install_pkgs "Intel microcode" intel-microcode
            ;;
        AuthenticAMD)
            log_info "Detected AMD CPU."
            install_pkgs "AMD microcode" amd64-microcode
            ;;
        *)
            log_warn "Could not detect CPU vendor from /proc/cpuinfo, skipping microcode."
            ;;
    esac
fi

# ---------------------------------------------------------------------------
# 3. fwupd — BIOS/UEFI + peripheral firmware updates via LVFS,
#    surfaced in Discover instead of a separate tool.
# ---------------------------------------------------------------------------
if ask "Install fwupd (firmware updates via LVFS, like Mint's Driver Manager)?"; then
    install_pkgs "fwupd" fwupd

    # gnome-firmware is an optional GTK front-end for fwupd — Cinnamon has
    # no built-in Discover-equivalent, so this is the closest "app you can
    # click" alternative to the CLI. Skipped silently if not in the repos.
    if apt-cache show gnome-firmware >/dev/null 2>&1; then
        install_pkgs "fwupd GUI front-end (gnome-firmware)" gnome-firmware
    fi

    if is_installed fwupd; then
        if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
            sudo systemctl enable --now fwupd >/dev/null 2>&1 || true
        elif command -v rc-service >/dev/null 2>&1 && [ -d /etc/runlevels ]; then
            sudo rc-update add fwupd default >/dev/null 2>&1 || true
            sudo rc-service fwupd start >/dev/null 2>&1 || true
        else
            sudo service fwupd start >/dev/null 2>&1 || true
        fi
        log_ok "fwupd installed. Check for firmware updates any time with: fwupdmgr get-updates"
        [ -x "$(command -v gnome-firmware)" ] && log_ok "...or via the 'Firmware' app (gnome-firmware) in the menu."
    fi
fi

echo -e "${GREEN}Hardware support step complete.${NC}"
log_warn "A reboot is recommended so newly installed firmware/microcode is loaded."
