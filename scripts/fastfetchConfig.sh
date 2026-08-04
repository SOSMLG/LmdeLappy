#!/usr/bin/env bash
# =======================================================
# fastfetch
# -------------------------------------------------------
# System info on terminal open. Pulls a set of curated
# config presets from the butterscripts repo (same source
# used elsewhere in this project's ecosystem).
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

if [[ $EUID -eq 0 ]]; then
    log_err "Do not run this as root."
    exit 1
fi

if ! command -v sudo &>/dev/null; then
    log_err "sudo not found."
    exit 1
fi

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} fastfetch${NC}"
echo -e "${CYAN}=========================================================${NC}"

# ---------------------------------------------------------------------------
# 1. Install fastfetch
# ---------------------------------------------------------------------------
if is_installed fastfetch; then
    log_ok "fastfetch already installed."
else
    log_info "Updating package lists..."
    sudo apt-get update -qq
    if sudo apt-get install -y fastfetch; then
        log_ok "fastfetch installed."
    else
        log_err "Failed to install fastfetch."
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 2. Config presets
# ---------------------------------------------------------------------------
if ask "Pull curated fastfetch presets (config/minimal/fancy/neon/debian-red/justaguy/server)?"; then
    FF_DIR="$HOME/.config/fastfetch"
    mkdir -p "$FF_DIR"
    BASE_URL="https://codeberg.org/justaguylinux/butterscripts/raw/branch/main/fastfetch"

    for f in config.jsonc minimal.jsonc fancy.jsonc neon.jsonc debian-red.jsonc justaguy.jsonc server.jsonc; do
        if wget -q "$BASE_URL/$f" -O "$FF_DIR/$f"; then
            log_info "  fetched $f"
        else
            log_warn "  failed to fetch $f (continuing)"
        fi
    done

    for img in debian_swirl.png justaguylinux.png; do
        wget -q "$BASE_URL/$img" -O "$FF_DIR/$img" || log_warn "  failed to fetch $img (continuing)"
    done

    # neon as the default preset — switch any time with:
    #   cp ~/.config/fastfetch/<preset>.jsonc ~/.config/fastfetch/config.jsonc
    if [[ -f "$FF_DIR/neon.jsonc" ]]; then
        cp "$FF_DIR/neon.jsonc" "$FF_DIR/config.jsonc"
        log_ok "Presets installed to $FF_DIR (neon set as default)"
    else
        log_warn "neon.jsonc didn't download — default config.jsonc from the loop above is used instead."
    fi
fi

log_ok "fastfetch setup complete. Try it: fastfetch"
