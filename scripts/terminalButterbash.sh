#!/usr/bin/env bash
# Installs ButterBash (bundled locally under ../butterbash so this works
# offline / without depending on the upstream repo still existing).
set -uo pipefail

RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; NC="\033[0m"

log_info() { echo -e "${CYAN}[*]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUTTERBASH_SRC="$SCRIPT_DIR/../butterbash"

if [[ $EUID -eq 0 ]]; then
    log_err "Do not run this as root — it installs into your own \$HOME/.config/bash and ~/.bashrc."
    exit 1
fi

if [ ! -d "$BUTTERBASH_SRC" ] || [ ! -f "$BUTTERBASH_SRC/install.sh" ]; then
    log_err "Bundled ButterBash not found at $BUTTERBASH_SRC"
    log_err "Expected the extracted butterbash-main archive to live at devuan-kde-setup/butterbash/"
    exit 1
fi

log_info "Installing ButterBash from $BUTTERBASH_SRC ..."

# ButterBash's own install.sh cd-relies on being run from inside its
# directory (it references ./bash and ./bashrc.example as relative paths).
if ( cd "$BUTTERBASH_SRC" && bash install.sh --yes ); then
    log_ok "ButterBash installed."
    echo -e "${YELLOW}Run 'source ~/.bashrc' or open a new terminal to use it.${NC}"
else
    log_err "ButterBash installation failed."
    exit 1
fi
