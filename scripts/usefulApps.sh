#!/usr/bin/env bash
# =======================================================
# Useful apps to fill the gaps left by cinnamonDebloat.sh
# -------------------------------------------------------
# VLC becomes the default media player. The rest are small
# helper packages (archive formats, thumbnailers) that make
# Nemo feel complete without pulling in a whole extra app suite.
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

echo -e "${CYAN}=========================================================${NC}"
echo -e "${CYAN} Useful Apps${NC}"
echo -e "${CYAN}=========================================================${NC}"

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

if ask "Install VLC (media player)?"; then
    install_pkgs "VLC" vlc

    # kdeDebloat.sh may have removed Dragon Player/Elisa earlier in this
    # toolkit's flow. If so, without this, common video/audio MIME types
    # can be left pointing at a now-uninstalled app instead of falling
    # over to VLC automatically.
    if is_installed vlc && command -v xdg-mime >/dev/null 2>&1; then
        log_info "Setting VLC as the default player for common video/audio types..."
        if xdg-mime default vlc.desktop \
            video/mp4 video/x-matroska video/webm video/x-msvideo video/quicktime video/mpeg \
            audio/mpeg audio/mp4 audio/flac audio/x-wav audio/ogg 2>/dev/null; then
            log_ok "VLC set as default for common video/audio types."
        else
            log_warn "Could not set MIME defaults (non-fatal — set manually via right-click > Open With if needed)."
        fi
    fi
fi

if ask "Install archive support for Nemo (7z, rar, right-click extract/compress)?"; then
    install_pkgs "Archive support" p7zip-full unrar-free file-roller nemo-fileroller
fi

if ask "Install Nemo file/video thumbnailers (previews for media, docs, RAW photos)?"; then
    install_pkgs "Thumbnailers" ffmpegthumbnailer gnome-video-effects raw-thumbnailer webp-pixbuf-loader
fi

if ask "Install qBittorrent (torrent client)?" "N"; then
    install_pkgs "qBittorrent" qbittorrent
fi

if ask "Install TLP (laptop battery/power management)?" "N"; then
    install_pkgs "TLP" tlp
    if is_installed tlp; then
        if command -v rc-update >/dev/null 2>&1 && [ -d /etc/runlevels ]; then
            sudo rc-update add tlp default 2>/dev/null
            sudo rc-service tlp start 2>/dev/null
        elif command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
            sudo systemctl enable --now tlp 2>/dev/null
        else
            sudo service tlp start 2>/dev/null
        fi || log_warn "Could not start the tlp service automatically — start it manually for your init system."
    fi
fi

echo -e "${GREEN}Useful apps step complete.${NC}"
