#!/usr/bin/env bash
# =======================================================
# Hotkeys — Mint/ohmydebn-inspired Cinnamon keyboard shortcuts
# -------------------------------------------------------
# Cinnamon's own defaults (Super = menu, Alt+Tab, Super+PageUp/Down for
# maximize/minimize, screenshot keys, etc.) are left alone — this only
# *adds* a small set of custom bindings for things Cinnamon has no
# built-in shortcut for: a one-key terminal, file manager, text editor,
# and (once installed) the OpenCode AI agent.
#
# No app launcher binding here on purpose — this toolkit skips rofi to
# stay lighter, and Cinnamon's own Menu applet (bound to Super by
# default) already covers app launching without an extra dependency.
#
# Idempotent: re-running this merges into your existing custom
# keybindings list via a small Python helper (already on any Debian/
# Devuan base) rather than clobbering bindings you've set yourself.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Hotkeys"

if ! command_exists gsettings; then
    log_err "gsettings not found — this needs to run inside an active Cinnamon/GTK session."
    exit 1
fi
if ! command_exists python3; then
    install_pkgs "python3 (needed to merge keybinding lists safely)" python3
fi

# name|command|binding
BINDINGS=(
    "Terminal|x-terminal-emulator|<Super>Return"
    "Terminal (alt)|x-terminal-emulator|<Primary><Alt>t"
    "File Manager|nemo|<Super>f"
    "Text Editor|xed|<Primary><Super>e"
    "System Monitor|x-terminal-emulator -e htop|<Primary><Shift>Escape"
)

log_info "This will add ${#BINDINGS[@]} custom keybindings to your Cinnamon session:"
for b in "${BINDINGS[@]}"; do
    IFS='|' read -r name cmd key <<< "$b"
    echo -e "   ${CYAN}${key}${NC} -> ${name} (${cmd})"
done
echo

if ! ask "Apply these keybindings now?"; then
    log_warn "Skipped."
    exit 0
fi

# ---------------------------------------------------------------------------
# Merge into the existing custom-list array (a gsettings array of dconf
# path strings) rather than overwriting it, using python3 for reliable
# array parsing instead of fragile string-splitting on gsettings' output.
# ---------------------------------------------------------------------------
MERGE_SCRIPT=$(mktemp --suffix=.py)
cat > "$MERGE_SCRIPT" << 'PYEOF'
import subprocess
import sys
import ast

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

bindings = sys.argv[1:]  # "name|cmd|key" triples flattened as separate argv entries
entries = [bindings[i:i+3] for i in range(0, len(bindings), 3)]

used_slots = set()
for path_frag in current:
    used_slots.add(path_frag)

next_index = 0
existing_names = {}
for slot in current:
    full_schema = f"{base_schema}.custom-keybinding"
    path = f"{prefix}/{slot}/"
    name = gget(f"{full_schema}:{path}", "name").strip("'")
    existing_names[name] = slot

changed = False
for name, cmd, key in entries:
    if name in existing_names:
        slot = existing_names[name]
        path = f"{prefix}/{slot}/"
    else:
        while f"custom{next_index}" in used_slots:
            next_index += 1
        slot = f"custom{next_index}"
        used_slots.add(slot)
        path = f"{prefix}/{slot}/"
        current.append(slot)
        changed = True

    full_schema = f"{base_schema}.custom-keybinding"
    gset(f"{full_schema}:{path}", "name", f"'{name}'")
    gset(f"{full_schema}:{path}", "command", f"'{cmd}'")
    gset(f"{full_schema}:{path}", "binding", f"['{key}']")

if changed:
    gset(base_schema, "custom-list", str(current).replace('"', "'"))

print("OK")
PYEOF

ARGS=()
for b in "${BINDINGS[@]}"; do
    IFS='|' read -r name cmd key <<< "$b"
    ARGS+=("$name" "$cmd" "$key")
done

if run_as_user python3 "$MERGE_SCRIPT" "${ARGS[@]}" | grep -q OK; then
    log_ok "Keybindings applied."
else
    log_err "Keybinding merge script failed — nothing was changed."
    rm -f "$MERGE_SCRIPT"
    exit 1
fi
rm -f "$MERGE_SCRIPT"

echo -e "${GREEN}Hotkeys step complete.${NC}"
log_warn "If a binding doesn't fire immediately, log out and back in (Cinnamon caches keybindings per-session)."
log_warn "Review/edit any of these later in Cinnamon Settings > Keyboard > Shortcuts > Custom Shortcuts."
