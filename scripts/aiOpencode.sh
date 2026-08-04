#!/usr/bin/env bash
# =======================================================
# AI: OpenCode
# -------------------------------------------------------
# Installs OpenCode (https://opencode.ai) — an open-source, terminal-based
# AI coding agent that works with Claude, GPT, Gemini, and other providers
# (bring your own API key, or use its free tier). This is the one piece
# cherry-picked wholesale from ohmydebn (https://github.com/dougburks/ohmydebn,
# MIT licensed) rather than reimplemented — same tool, same idea (a
# Super+A hotkey that installs-then-launches on first press), adapted
# here to run under a terminal emulator instead of Alacritty specifically,
# since this toolkit doesn't install a specific terminal for you.
#
# Also drops a small "skill" file describing this system, in the format
# OpenCode (and Claude Code, if you use it too) can read for repo/system
# context — same concept as ohmydebn's own AI skill file.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "AI: OpenCode"

if command_exists opencode; then
    log_ok "OpenCode already installed ($(opencode --version 2>/dev/null || echo 'version unknown'))."
else
    echo -e "${CYAN}OpenCode can be installed two ways:${NC}"
    echo "  1) Official script: curl -fsSL https://opencode.ai/install | bash"
    echo "     (downloads a prebuilt binary straight from opencode.ai — fastest, but"
    echo "      piping curl to bash means trusting that script sight-unseen)"
    echo "  2) npm: npm install -g opencode-ai"
    echo "     (goes through the npm registry instead — needs Node.js/npm installed first)"
    echo
    read -rp "$(echo -e "${YELLOW}Install via [1] official script, [2] npm, or [N] skip? (1/2/N): ${NC}")" METHOD

    case "$METHOD" in
        1)
            log_info "Running the official OpenCode installer..."
            if curl -fsSL https://opencode.ai/install | bash; then
                log_ok "OpenCode installed."
            else
                log_err "OpenCode installation failed."
            fi
            ;;
        2)
            if ! command_exists npm; then
                log_info "npm not found — installing Node.js LTS + npm first."
                install_pkgs "Node.js + npm" nodejs npm
            fi
            if command_exists npm; then
                log_info "Installing opencode-ai via npm..."
                if sudo npm install -g opencode-ai; then
                    log_ok "OpenCode installed via npm."
                else
                    log_err "npm install failed."
                fi
            else
                log_err "npm still not available — skipping."
            fi
            ;;
        *)
            log_warn "Skipped OpenCode installation."
            ;;
    esac
fi

# Make sure ~/.opencode/bin (the official installer's default location) or
# $HOME/bin is on PATH for future shells, without duplicating the line.
for CANDIDATE in "$HOME/.opencode/bin" "$HOME/bin"; do
    if [ -d "$CANDIDATE" ] && ! grep -qF "$CANDIDATE" "$HOME/.bashrc" 2>/dev/null; then
        echo "export PATH=\"$CANDIDATE:\$PATH\"" >> "$HOME/.bashrc"
        log_ok "Added $CANDIDATE to PATH in ~/.bashrc"
    fi
done

# ---------------------------------------------------------------------------
# Hotkey: Super+A -> open a terminal running opencode (installs-then-runs
# check happens implicitly since we only reach here after the install step
# above; if you skipped installing, the binding just won't find the command).
# ---------------------------------------------------------------------------
if command_exists gsettings && ask "Bind Super+A to launch OpenCode in a terminal?"; then
    if command_exists python3; then
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

name, cmd, key = "OpenCode AI", "x-terminal-emulator -e opencode", "<Super>a"
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
            log_ok "Super+A now opens OpenCode in a terminal."
        else
            log_warn "Could not set the keybinding automatically — bind it yourself in"
            log_warn "Cinnamon Settings > Keyboard > Shortcuts > Custom, command: x-terminal-emulator -e opencode"
        fi
        rm -f "$MERGE_SCRIPT"
    fi
else
    log_info "No active Cinnamon session detected (or you skipped) — bind Super+A manually later if you want it."
fi

# ---------------------------------------------------------------------------
# System skill file — same idea as ohmydebn's own "skill that all these AI
# tools can use to understand the underlying platform." OpenCode and
# Claude Code both look for AGENTS.md / CLAUDE.md / a skills directory
# depending on version; this drops a plain, tool-agnostic markdown file
# in both common locations so whichever one you use picks it up.
# ---------------------------------------------------------------------------
if ask "Install a system 'skill' file so AI tools know this is a Devuan/OpenRC/Cinnamon box?"; then
    SKILL_SRC="$SCRIPT_DIR/../skills/devuan-cinnamon-SKILL.md"
    if [ -f "$SKILL_SRC" ]; then
        mkdir -p "$HOME/.config/opencode"
        cp "$SKILL_SRC" "$HOME/.config/opencode/AGENTS.md" 2>/dev/null \
            && log_ok "Installed to ~/.config/opencode/AGENTS.md"
        if [ ! -f "$HOME/AGENTS.md" ]; then
            cp "$SKILL_SRC" "$HOME/AGENTS.md" 2>/dev/null \
                && log_ok "Also installed to ~/AGENTS.md (picked up by most terminal AI agents run from \$HOME)."
        fi
    else
        log_warn "Skill file not found at $SKILL_SRC — skipping."
    fi
fi

echo -e "${GREEN}AI (OpenCode) step complete.${NC}"
log_info "Run 'opencode auth login' once to connect a provider (or use its free tier), then just 'opencode' to start."
