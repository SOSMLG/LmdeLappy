#!/usr/bin/env bash
# =======================================================
# Fancy Cinnamon — theming/productivity pass inspired by two Linux Mint
# YouTube walkthroughs (a "make it look modern" appearance video and a
# "do this after installing" essentials video)
# -------------------------------------------------------
# Everything here is either:
#   (a) a built-in Cinnamon feature, toggled via dconf — zero extra
#       dependency, zero third-party code, or
#   (b) a real Cinnamon Spice pulled directly from the official
#       linuxmint/cinnamon-spices-{extensions,applets} GitHub repos via
#       lib/install-spice.py, with every UUID below verified by hand
#       against those repos rather than guessed.
#
# What's deliberately left out from the videos: manually browsing
# gnome-look.org for a specific community theme/icon/cursor pack (no
# stable way to script "the exact one shown in the video" reliably —
# mintLook.sh already covers the actual Mint-Y look), and the sponsor
# segment. Desktop Cube / Flipper were also left out — real spices, but
# their exact current UUIDs weren't confidently verified, and 3D
# compositor effects are the most failure-prone category of these
# extensions; install them yourself from Cinnamon Settings > Extensions
# > Download if you want them, same one-click process as everything else
# in that screen.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Fancy Cinnamon"

if ! command_exists python3; then
    install_pkgs "python3 (needed for the spice installer / dconf helpers)" python3
fi

SPICE_INSTALLER="$SCRIPT_DIR/../lib/install-spice.py"
LIST_ADD="$SCRIPT_DIR/../lib/dconf-list-add.py"
APPLET_ADD="$SCRIPT_DIR/../lib/panel-applet-add.py"
EXT_DIR="$HOME/.local/share/cinnamon/extensions"
APPLET_DIR="$HOME/.local/share/cinnamon/applets"
HAVE_SESSION=0
command_exists gsettings && HAVE_SESSION=1

install_extension() {
    # $1 = uuid, $2 = human label
    local uuid="$1" label="$2"
    if [ -d "$EXT_DIR/$uuid" ]; then
        log_ok "$label already downloaded."
    else
        log_info "Downloading $label ($uuid) from cinnamon-spices-extensions..."
        if run_as_user python3 "$SPICE_INSTALLER" extensions "$uuid" "$EXT_DIR" | grep -q OK; then
            log_ok "$label downloaded."
        else
            log_warn "Could not download $label — skipping (network issue, or GitHub API rate limit; safe to retry later)."
            return 1
        fi
    fi
    if [ "$HAVE_SESSION" -eq 1 ]; then
        run_as_user python3 "$LIST_ADD" org.cinnamon enabled-extensions "$uuid" >/dev/null
        log_ok "$label enabled."
    fi
}

install_applet() {
    # $1 = uuid, $2 = human label, $3 = optional package deps (space-separated)
    local uuid="$1" label="$2" deps="${3:-}"
    if [ -n "$deps" ]; then
        # shellcheck disable=SC2086
        install_pkgs "$label dependencies" $deps
    fi
    if [ -d "$APPLET_DIR/$uuid" ]; then
        log_ok "$label already downloaded."
    else
        log_info "Downloading $label ($uuid) from cinnamon-spices-applets..."
        if run_as_user python3 "$SPICE_INSTALLER" applets "$uuid" "$APPLET_DIR" | grep -q OK; then
            log_ok "$label downloaded."
        else
            log_warn "Could not download $label — skipping."
            return 1
        fi
    fi
    if [ "$HAVE_SESSION" -eq 1 ]; then
        run_as_user python3 "$APPLET_ADD" "$uuid" >/dev/null
        log_ok "$label added to the panel."
    fi
}

# ---------------------------------------------------------------------------
# 1. Custom UI font — Inter, fetched straight from google/fonts on GitHub
#    (the exact same font the first video downloads from fonts.google.com,
#    just pulled from source instead of needing a browser).
# ---------------------------------------------------------------------------
if ask "Install and apply the Inter font as your UI font (like the video)?"; then
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    if [ -f "$FONT_DIR/Inter.ttf" ]; then
        log_ok "Inter already installed."
    else
        log_info "Fetching Inter (variable font) from google/fonts..."
        API_URL="https://api.github.com/repos/google/fonts/contents/ofl/inter"
        DL_URL=$(curl -fsSL "$API_URL" 2>/dev/null | python3 -c '
import json, sys
try:
    entries = json.load(sys.stdin)
    for e in entries:
        if e.get("name") == "Inter[opsz,wght].ttf":
            print(e["download_url"])
            break
except Exception:
    pass
' 2>/dev/null)
        if [ -n "$DL_URL" ] && curl -fsSL -o "$FONT_DIR/Inter.ttf" "$DL_URL"; then
            fc-cache -f "$FONT_DIR" >/dev/null 2>&1
            log_ok "Inter installed to $FONT_DIR"
        else
            log_warn "Could not fetch Inter from GitHub — skipping font install (nothing else here depends on it)."
        fi
    fi

    if [ -f "$FONT_DIR/Inter.ttf" ] && [ "$HAVE_SESSION" -eq 1 ]; then
        user_gsettings set org.cinnamon.desktop.interface font-name "Inter 10"
        user_gsettings set org.cinnamon.desktop.interface document-font-name "Inter 10"
        user_gsettings set org.cinnamon.desktop.wm.preferences titlebar-font "Inter Bold 10"
        log_ok "Inter applied as the desktop/document/window-title font."
    fi
fi

# ---------------------------------------------------------------------------
# 2. Cinnamon Maximus — hides the window titlebar on maximized windows
#    (the "annoying system title bar gone" moment from the video).
# ---------------------------------------------------------------------------
if ask "Install Cinnamon Maximus (hide the titlebar on maximized windows)?"; then
    install_extension "cinnamon-maximus@fmete" "Cinnamon Maximus"
fi
log_info "(Tip if you use it: hold Alt and nudge the mouse to get the titlebar/close button back temporarily.)"

# ---------------------------------------------------------------------------
# 3. Blur Cinnamon — blurs the panel/menu background to blend with your
#    wallpaper, same effect as the video's "blur cinnamon" extension.
# ---------------------------------------------------------------------------
if ask "Install Blur Cinnamon (blur the panel/menu to match your wallpaper)?"; then
    install_extension "BlurCinnamon@klangman" "Blur Cinnamon"
    log_info "Configure it from its own settings (gear icon in Extensions) — enable 'pop-up menus' there for the full effect shown in the video."
fi

# ---------------------------------------------------------------------------
# 4. gTile — window-tiling grid, Super+G by default. This is the
#    productivity/"easier" pick from the videos, not just eye candy.
# ---------------------------------------------------------------------------
if ask "Install gTile (window tiling grid, opens with Super+G)?"; then
    install_extension "gTile@shuairan" "gTile"
fi

# ---------------------------------------------------------------------------
# 5. Panel applets: Workspace Switcher + Window List. Both ship inside
#    Cinnamon itself — no download, just added to the panel.
# ---------------------------------------------------------------------------
if [ "$HAVE_SESSION" -eq 1 ] && ask "Add Workspace Switcher + Window List applets to the panel?"; then
    run_as_user python3 "$APPLET_ADD" "workspace-switcher@cinnamon.org" "panel1:right" "1" >/dev/null \
        && log_ok "Workspace Switcher added."
    run_as_user python3 "$APPLET_ADD" "window-list@cinnamon.org" "panel1:right" "2" >/dev/null \
        && log_ok "Window List added."
    log_info "Right-click the panel > Applets to reposition/configure them (e.g. Workspace Switcher's display style)."
fi

# ---------------------------------------------------------------------------
# 6. Alt-Tab switcher style -> Coverflow (built-in, dconf only)
# ---------------------------------------------------------------------------
if [ "$HAVE_SESSION" -eq 1 ] && ask "Switch Alt-Tab to the Coverflow style?"; then
    user_gsettings set org.cinnamon alttab-switcher-style "coverflow" \
        && log_ok "Alt-Tab style set to Coverflow." \
        || log_warn "Could not set Alt-Tab style (try Cinnamon Settings > Windows > Alt-Tab manually)."
fi

# ---------------------------------------------------------------------------
# 7. Night Light — built into Cinnamon 6.4+ (Debian trixie ships 6.4).
#    On an older Cinnamon this key simply won't exist; the gsettings call
#    fails harmlessly and we say so.
# ---------------------------------------------------------------------------
if [ "$HAVE_SESSION" -eq 1 ] && ask "Enable Night Light (reduces blue light in the evening, follows sunset/sunrise)?"; then
    if user_gsettings set org.cinnamon.settings-daemon.plugins.color night-light-enabled true; then
        user_gsettings set org.cinnamon.settings-daemon.plugins.color night-light-schedule-automatic true
        log_ok "Night Light enabled (automatic sunset/sunrise schedule)."
    else
        log_warn "Night Light isn't available (needs Cinnamon 6.4+ — check Cinnamon Settings > Display for a Night Light section)."
    fi
fi

# ---------------------------------------------------------------------------
# 8. Lock-screen hotkey — Super+L, same convenience step as the essentials
#    video's "set a shortcut for locking the screen."
# ---------------------------------------------------------------------------
if [ "$HAVE_SESSION" -eq 1 ] && ask "Bind Super+L to lock the screen?"; then
    MERGE_SCRIPT=$(mktemp --suffix=.py)
    cat > "$MERGE_SCRIPT" << 'PYEOF'
import subprocess, ast
base_schema = "org.cinnamon.desktop.keybindings"
prefix = "/org/cinnamon/desktop/keybindings/custom-keybindings"

def gget(schema, key):
    out = subprocess.run(["gsettings", "get", schema, key], capture_output=True, text=True)
    return out.stdout.strip()

def gset(schema, key, value):
    subprocess.run(["gsettings", "set", schema, key, value], check=False)

raw = gget(base_schema, "custom-list")
try:
    current = ast.literal_eval(raw) if raw else []
    if not isinstance(current, list):
        current = []
except Exception:
    current = []

existing_names = {}
for slot in current:
    path = f"{prefix}/{slot}/"
    name = gget(f"{base_schema}.custom-keybinding:{path}", "name").strip("'")
    existing_names[name] = slot

name, cmd, key = "Lock Screen", "cinnamon-screensaver-command --lock", "<Super>l"
if name in existing_names:
    slot = existing_names[name]
else:
    i = 0
    used = set(current)
    while f"custom{i}" in used:
        i += 1
    slot = f"custom{i}"
    current.append(slot)

path = f"{prefix}/{slot}/"
gset(f"{base_schema}.custom-keybinding:{path}", "name", f"'{name}'")
gset(f"{base_schema}.custom-keybinding:{path}", "command", f"'{cmd}'")
gset(f"{base_schema}.custom-keybinding:{path}", "binding", f"['{key}']")
gset(base_schema, "custom-list", str(current).replace('"', "'"))
print("OK")
PYEOF
    if run_as_user python3 "$MERGE_SCRIPT" | grep -q OK; then
        log_ok "Super+L now locks the screen."
    else
        log_warn "Could not set the binding — Cinnamon may already have this bound by default; check Keyboard > Shortcuts > System."
    fi
    rm -f "$MERGE_SCRIPT"
fi

# ---------------------------------------------------------------------------
# 9. Purely cosmetic extras — off by default. Window open/close/minimize
#    shader effects (from the same author who ported GNOME's Burn-My-Windows
#    and a magic-lamp minimize effect to Cinnamon) and a screen color
#    picker applet with an older, dependency-heavy history. Fun, but the
#    most likely things here to have a rough edge — hence opt-in.
# ---------------------------------------------------------------------------
if ask "Install Magic Lamp Effect (genie-style minimize animation)?" "N"; then
    install_extension "CinnamonMagicLamp@klangman" "Magic Lamp Effect"
fi

if ask "Install Burn My Windows (animated window open/close effects)?" "N"; then
    install_extension "CinnamonBurnMyWindows@klangman" "Burn My Windows"
    log_info "Pick your effects from its own settings (gear icon in Extensions) — dozens of presets available."
fi

if ask "Install the Color Picker applet (pick a color from anywhere on screen)?" "N"; then
    install_applet "color-picker@fmete" "Color Picker" "python3-numpy python3-xlib"
fi

echo -e "${GREEN}Fancy Cinnamon step complete.${NC}"
if [ "$HAVE_SESSION" -eq 0 ]; then
    log_warn "No active Cinnamon session detected — extensions were downloaded but not enabled, and dconf steps"
    log_warn "were skipped. Re-run this script once logged into Cinnamon locally to finish applying everything."
else
    log_warn "New extensions/applets usually need a Cinnamon restart to show up: press Alt+F2, type 'r', Enter"
    log_warn "(or just log out and back in)."
fi
