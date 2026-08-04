#!/usr/bin/env bash
# =======================================================
# Mint Look — LMDE 7 "Gigi"-style theming for Devuan Cinnamon
# -------------------------------------------------------
# This is the script that actually makes a stock Devuan Cinnamon
# desktop look like LMDE: Mint-Y icons + theme, a Mint-like cursor,
# and a Mint-Y-toned wallpaper, applied via dconf to the current
# user's Cinnamon session.
#
# Deliberately does NOT add Linux Mint's own APT repository —
# that needs GPG key management, a correct suite/codename match
# to your Debian base, and leaves a third-party signed source
# sitting on the system permanently. Instead this uses two
# fallbacks, cleanest-first:
#   1. mint-y-icons / mint-x-icons straight from Debian's own repo
#      (packaged and maintained by the Debian Cinnamon Team — no
#      extra source needed, this is the same path installPhotogimp.sh
#      already uses for pulling a GitHub release: check what's
#      really there before acting).
#   2. mint-themes (the GTK/Cinnamon theme itself) and a Mint-like
#      cursor theme, built locally from upstream source the same
#      way installPhotogimp.sh does — latest GitHub release tag,
#      falls back to a pinned known-good tag if the API is
#      unavailable, verified before use, nothing added to
#      /etc/apt/sources.list.d.
# =======================================================

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Mint Look (LMDE 7-style theming)"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

THEMES_DIR="$HOME/.themes"
ICONS_DIR="$HOME/.icons"
mkdir -p "$THEMES_DIR" "$ICONS_DIR"

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

# ---------------------------------------------------------------------------
# 1. Mint-Y / Mint-X icon themes — real Debian packages, no extra repo.
# ---------------------------------------------------------------------------
if ask "Install Mint-Y and Mint-X icon themes (from Debian's own repo)?"; then
    if apt-cache show mint-y-icons >/dev/null 2>&1; then
        install_pkgs "Mint icon themes" mint-y-icons mint-x-icons
    else
        log_warn "mint-y-icons isn't in your configured repos (needs Debian's 'gnome' section enabled)."
        log_warn "Skipping — the theme step below still works without it, just with a generic icon set."
    fi
fi

# ---------------------------------------------------------------------------
# 2. Mint-Y GTK/Cinnamon theme — built from upstream source (linuxmint/mint-themes)
#    since it isn't reliably packaged for Debian the way the icon themes are.
# ---------------------------------------------------------------------------
MINT_THEME_INSTALLED=0
if ask "Install the Mint-Y GTK/Cinnamon theme (built from linuxmint/mint-themes source)?"; then
    if [ -d "$THEMES_DIR/Mint-Y" ]; then
        log_ok "Mint-Y theme already present in $THEMES_DIR — skipping rebuild."
        MINT_THEME_INSTALLED=1
    else
        install_pkgs "Theme build dependencies" python3 sassc gtk2-engines-murrine gtk2-engines-pixbuf

        log_info "Looking up the latest mint-themes release tag..."
        TAG=$(curl -fsSL https://api.github.com/repos/linuxmint/mint-themes/releases/latest 2>/dev/null \
            | grep -oP '"tag_name":\s*"\K[^"]+' | head -1)
        if [ -z "$TAG" ]; then
            log_warn "GitHub API lookup failed, using pinned fallback tag..."
            TAG="2.2.3"
        fi
        log_info "Using mint-themes ${TAG}"

        ARCHIVE="$WORK_DIR/mint-themes.tar.gz"
        if curl -fsSL -o "$ARCHIVE" "https://codeload.github.com/linuxmint/mint-themes/tar.gz/refs/tags/${TAG}"; then
            mkdir -p "$WORK_DIR/mint-themes"
            tar -xzf "$ARCHIVE" -C "$WORK_DIR/mint-themes" --strip-components=1

            if [ -f "$WORK_DIR/mint-themes/generate-themes.py" ]; then
                log_info "Building themes (generate-themes.py)..."
                if ( cd "$WORK_DIR/mint-themes" && python3 generate-themes.py >/dev/null 2>&1 ); then
                    if [ -d "$WORK_DIR/mint-themes/usr/share/themes" ]; then
                        cp -r "$WORK_DIR/mint-themes/usr/share/themes/." "$THEMES_DIR/"
                        log_ok "Mint-Y/Mint-X theme variants installed to $THEMES_DIR"
                        MINT_THEME_INSTALLED=1
                    else
                        log_warn "generate-themes.py ran but the expected usr/share/themes output wasn't found."
                    fi
                else
                    log_warn "Theme generation script failed — skipping (this is cosmetic-only, nothing else depends on it)."
                fi
            else
                log_warn "generate-themes.py not found in the downloaded source — layout may have changed upstream. Skipping."
            fi
        else
            log_warn "Could not download mint-themes source — skipping (check network / GitHub reachability)."
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 3. Cursor theme — Bibata if Debian has it, otherwise leave the existing
#    default alone rather than fighting with a manual build for a cursor.
# ---------------------------------------------------------------------------
CURSOR_THEME=""
if ask "Install a Mint-like cursor theme (Bibata, if available in your repos)?"; then
    if apt-cache show bibata-cursor-theme >/dev/null 2>&1; then
        install_pkgs "Bibata cursor theme" bibata-cursor-theme
        CURSOR_THEME="Bibata-Modern-Classic"
    else
        log_warn "bibata-cursor-theme not available in your configured repos — leaving the current cursor theme as-is."
    fi
fi

# ---------------------------------------------------------------------------
# 4. Wallpaper — generated locally (no download needed) in a Mint-Y-toned
#    gradient, so this step never depends on network availability. Skips
#    cleanly if ImageMagick isn't present rather than force-installing a
#    whole new dependency just for a background image.
# ---------------------------------------------------------------------------
WALLPAPER_PATH="$HOME/.local/share/backgrounds/devuan-cinnamon-mint-y.png"
if ask "Generate a Mint-Y-toned wallpaper (local, no download — needs ImageMagick)?"; then
    if ! command_exists convert; then
        install_pkgs "ImageMagick" imagemagick
    fi
    if command_exists convert; then
        mkdir -p "$(dirname "$WALLPAPER_PATH")"
        # Mint-Y's signature palette: dark charcoal fading to the Mint-Y green accent.
        if convert -size 1920x1080 gradient:'#1c1e22'-'#2f4538' \
            \( -size 1920x1080 xc:none -fill '#8bc34a' -draw "circle 1600,900 1900,900" -blur 0x200 \) \
            -compose over -composite "$WALLPAPER_PATH" 2>/dev/null; then
            log_ok "Wallpaper generated at $WALLPAPER_PATH"
        else
            log_warn "ImageMagick composite failed — skipping wallpaper (cosmetic only)."
            WALLPAPER_PATH=""
        fi
    else
        log_warn "ImageMagick unavailable — skipping wallpaper generation."
        WALLPAPER_PATH=""
    fi
fi

# ---------------------------------------------------------------------------
# 5. Apply everything to the current Cinnamon session via dconf/gsettings.
#    This only touches the invoking user's own settings — never system-wide
#    defaults — same scoping as kdeDebloat.sh's animation-speed tweak.
# ---------------------------------------------------------------------------
if ask "Apply the theme/icons/cursor/wallpaper to your current Cinnamon session now?"; then
    APPLIED=0

    if [ "$MINT_THEME_INSTALLED" -eq 1 ] || [ -d "$THEMES_DIR/Mint-Y" ] || [ -d "/usr/share/themes/Mint-Y" ]; then
        user_gsettings set org.cinnamon.theme name "Mint-Y" && APPLIED=1
        user_gsettings set org.cinnamon.desktop.interface gtk-theme "Mint-Y" && APPLIED=1
        user_gsettings set org.cinnamon.desktop.wm.preferences theme "Mint-Y" && APPLIED=1
        log_ok "Applied Mint-Y as the Cinnamon/GTK/window-manager theme."
    else
        log_warn "No Mint-Y theme found on disk — skipping theme application (icons/cursor/wallpaper still apply below)."
    fi

    if is_installed mint-y-icons; then
        user_gsettings set org.cinnamon.desktop.interface icon-theme "Mint-Y" && APPLIED=1
        log_ok "Applied Mint-Y as the icon theme."
    fi

    if [ -n "$CURSOR_THEME" ]; then
        user_gsettings set org.cinnamon.desktop.interface cursor-theme "$CURSOR_THEME" && APPLIED=1
        log_ok "Applied $CURSOR_THEME as the cursor theme."
    fi

    if [ -n "$WALLPAPER_PATH" ] && [ -f "$WALLPAPER_PATH" ]; then
        user_gsettings set org.cinnamon.desktop.background picture-uri "file://$WALLPAPER_PATH" && APPLIED=1
        user_gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_PATH" 2>/dev/null
        log_ok "Wallpaper set."
    fi

    if [ "$APPLIED" -eq 0 ]; then
        log_warn "Nothing was applied — likely no active Cinnamon session (e.g. running this over SSH before first login)."
        log_warn "Re-run this script (or just the 'apply' prompt) once logged into Cinnamon locally."
    fi
fi

echo -e "${GREEN}Mint Look step complete.${NC}"
log_warn "If anything looks half-applied, log out and back in — Cinnamon caches some theme state per-session."
