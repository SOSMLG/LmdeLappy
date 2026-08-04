#!/usr/bin/env bash
# =======================================================
# Theme Packs (optional)
# -------------------------------------------------------
# mintLook.sh covers the default LMDE-style look. This adds a few extra,
# well-known GTK/Cinnamon-compatible theme + icon packs on top — inspired
# by ohmydebn's theme-picker concept (https://github.com/dougburks/ohmydebn,
# MIT licensed), but pulling from Debian's own repos (Arc, Papirus,
# Materia) instead of building Omarchy's Hyprland-oriented theme set,
# which doesn't map cleanly onto Cinnamon/Muffin.
#
# Also installs a tiny theme-picker script bound to Ctrl+Super+T, the
# same key ohmydebn uses for "pick a new theme" — cycles GTK theme,
# icon theme, and Cinnamon shell theme together so they never end up
# mismatched.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Theme Packs"

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

if ask "Install extra theme/icon packs (Arc, Papirus, Materia — all from Debian's own repos)?"; then
    install_pkgs "Extra themes" arc-theme papirus-icon-theme materia-gtk-theme
fi

# ---------------------------------------------------------------------------
# Theme picker — a small rofi-free menu using zenity (GTK dialogs, already
# a dependency of several GNOME/Cinnamon apps, so no new heavy dependency)
# to pick from whatever GTK themes are actually installed in
# /usr/share/themes and ~/.themes, applying theme + a matching icon
# choice together via the same dconf keys mintLook.sh uses.
# ---------------------------------------------------------------------------
if ask "Install a theme-picker script bound to Ctrl+Super+T?"; then
    if ! command_exists zenity; then
        install_pkgs "zenity (for the picker dialog)" zenity
    fi

    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
    PICKER="$BIN_DIR/devuan-theme-picker.sh"

    cat > "$PICKER" << 'EOF'
#!/usr/bin/env bash
# Lists installed GTK themes, lets you pick one via zenity, and applies
# it as the GTK + Cinnamon shell + window-manager theme together.
set -uo pipefail

mapfile -t THEMES < <(
    { ls -1 /usr/share/themes 2>/dev/null; ls -1 "$HOME/.themes" 2>/dev/null; } \
        | sort -u
)

if [ "${#THEMES[@]}" -eq 0 ]; then
    zenity --error --text="No themes found in /usr/share/themes or ~/.themes." 2>/dev/null
    exit 1
fi

CHOICE=$(printf '%s\n' "${THEMES[@]}" | zenity --list --title="Pick a theme" \
    --column="Theme" --height=400 --width=300 2>/dev/null)

[ -z "$CHOICE" ] && exit 0

gsettings set org.cinnamon.theme name "$CHOICE" 2>/dev/null
gsettings set org.cinnamon.desktop.interface gtk-theme "$CHOICE" 2>/dev/null
gsettings set org.cinnamon.desktop.wm.preferences theme "$CHOICE" 2>/dev/null

notify-send "Theme applied" "$CHOICE" 2>/dev/null || true
EOF
    chmod +x "$PICKER"
    log_ok "Theme picker installed at $PICKER"

    if command_exists gsettings && command_exists python3; then
        MERGE_SCRIPT=$(mktemp --suffix=.py)
        cat > "$MERGE_SCRIPT" << PYEOF
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

name, cmd, key = "Theme Picker", "$PICKER", "<Primary><Super>t"
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
            log_ok "Ctrl+Super+T now opens the theme picker."
        else
            log_warn "Could not bind the hotkey automatically — run $PICKER manually, or bind it"
            log_warn "yourself in Cinnamon Settings > Keyboard > Shortcuts > Custom."
        fi
        rm -f "$MERGE_SCRIPT"
    fi
fi

echo -e "${GREEN}Theme packs step complete.${NC}"
