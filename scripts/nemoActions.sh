#!/usr/bin/env bash
# =======================================================
# Nemo Actions — right-click context menu additions
# -------------------------------------------------------
# Recreates the most useful "Nemo Actions" moments from the appearance
# video (one-click PDF compression, one-click image compression, "Open
# in VS Code") self-written rather than downloaded from Cinnamon Spices'
# Actions category — these are simple enough that writing them directly
# means no dependency on a third-party action's exact current behavior,
# and it means "Open in OpenCode" can exist at all (nobody's published a
# Spice action for a tool that didn't exist when most of those were
# written).
#
# Each action is a small wrapper script in ~/.local/bin (so the logic is
# one command, easy to read/edit) plus a .nemo_action file in
# ~/.local/share/nemo/actions/ that adds it to the right-click menu.
# Nemo picks up new actions live in most versions; if one doesn't show
# up, 'nemo -q' (it relaunches on the next folder you open) forces it.
# =======================================================
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

require_not_root
log_head "Nemo Actions"

log_info "Refreshing package lists..."
sudo apt-get update || { log_err "apt-get update failed, aborting."; exit 1; }

BIN_DIR="$HOME/.local/bin"
ACTIONS_DIR="$HOME/.local/share/nemo/actions"
mkdir -p "$BIN_DIR" "$ACTIONS_DIR"

INSTALLED_ANY=0

# ---------------------------------------------------------------------------
# 1. Compress PDF (Ghostscript, /ebook preset — a solid size/quality
#    balance, same idea as the video's one-click PDF shrink).
# ---------------------------------------------------------------------------
if ask "Add 'Compress PDF' to the right-click menu (Ghostscript)?"; then
    install_pkgs "Ghostscript" ghostscript

    cat > "$BIN_DIR/devuan-nemo-compress-pdf.sh" << 'EOF'
#!/usr/bin/env bash
# Compresses each given PDF to "<name>-compressed.pdf" alongside the original.
set -uo pipefail
OK=0; FAIL=0
for f in "$@"; do
    [ -f "$f" ] || continue
    out="${f%.pdf}-compressed.pdf"
    if gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook \
          -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$out" "$f" 2>/dev/null; then
        OK=$((OK+1))
    else
        FAIL=$((FAIL+1))
    fi
done
if command -v notify-send >/dev/null 2>&1; then
    notify-send -i application-pdf "PDF compression done" "${OK} compressed, ${FAIL} failed." 2>/dev/null || true
fi
EOF
    chmod +x "$BIN_DIR/devuan-nemo-compress-pdf.sh"

    cat > "$ACTIONS_DIR/devuan-compress-pdf.nemo_action" << EOF
[Nemo Action]
Name=Compress PDF
Comment=Shrink this PDF with Ghostscript
Exec=$BIN_DIR/devuan-nemo-compress-pdf.sh %F
Icon-Name=application-pdf
Selection=any
Extensions=pdf;
EscapeSpaces=true
EOF
    log_ok "'Compress PDF' added."
    INSTALLED_ANY=1
fi

# ---------------------------------------------------------------------------
# 2. Compress Image (ImageMagick, quality 85 — visually lossless for
#    photos, meaningfully smaller files).
# ---------------------------------------------------------------------------
if ask "Add 'Compress Image' to the right-click menu (ImageMagick)?"; then
    install_pkgs "ImageMagick" imagemagick

    cat > "$BIN_DIR/devuan-nemo-compress-image.sh" << 'EOF'
#!/usr/bin/env bash
# Compresses each given image to "<name>-compressed.<ext>" alongside the original.
set -uo pipefail
OK=0; FAIL=0
for f in "$@"; do
    [ -f "$f" ] || continue
    ext="${f##*.}"
    base="${f%.*}"
    out="${base}-compressed.${ext}"
    if convert "$f" -strip -quality 85 "$out" 2>/dev/null; then
        OK=$((OK+1))
    else
        FAIL=$((FAIL+1))
    fi
done
if command -v notify-send >/dev/null 2>&1; then
    notify-send -i image-x-generic "Image compression done" "${OK} compressed, ${FAIL} failed." 2>/dev/null || true
fi
EOF
    chmod +x "$BIN_DIR/devuan-nemo-compress-image.sh"

    cat > "$ACTIONS_DIR/devuan-compress-image.nemo_action" << EOF
[Nemo Action]
Name=Compress Image
Comment=Shrink this image with ImageMagick (quality 85)
Exec=$BIN_DIR/devuan-nemo-compress-image.sh %F
Icon-Name=image-x-generic
Selection=any
Extensions=jpg;jpeg;png;webp;bmp;tiff;
EscapeSpaces=true
EOF
    log_ok "'Compress Image' added."
    INSTALLED_ANY=1
fi

# ---------------------------------------------------------------------------
# 3. Open in VS Code — right-click a folder, open it as a VS Code
#    workspace. Only shows up if VSCodium/VS Code is actually on PATH.
# ---------------------------------------------------------------------------
if ask "Add 'Open in VS Code' to folder right-click menus?"; then
    CODE_BIN=""
    for candidate in code codium; do
        command_exists "$candidate" && CODE_BIN="$candidate" && break
    done
    if [ -z "$CODE_BIN" ]; then
        log_warn "Neither 'code' nor 'codium' found on PATH — install VSCodium first (scripts/installVscodium.sh),"
        log_warn "then re-run this step. Skipping for now."
    else
        cat > "$BIN_DIR/devuan-nemo-open-vscode.sh" << EOF
#!/usr/bin/env bash
exec $CODE_BIN "\$@"
EOF
        chmod +x "$BIN_DIR/devuan-nemo-open-vscode.sh"

        cat > "$ACTIONS_DIR/devuan-open-vscode.nemo_action" << EOF
[Nemo Action]
Name=Open in VS Code
Comment=Open this folder in VS Code / VSCodium
Exec=$BIN_DIR/devuan-nemo-open-vscode.sh %F
Icon-Name=vscodium
Selection=s
Extensions=dir;
EscapeSpaces=true
EOF
        log_ok "'Open in VS Code' added (using '$CODE_BIN')."
        INSTALLED_ANY=1
    fi
fi

# ---------------------------------------------------------------------------
# 4. Open in OpenCode — right-click a folder, open a terminal there
#    running OpenCode. The one action here with no video/spice precedent
#    — ties directly into aiOpencode.sh.
# ---------------------------------------------------------------------------
if ask "Add 'Open in OpenCode' to folder right-click menus?"; then
    if ! command_exists opencode; then
        log_warn "'opencode' not found on PATH — install it first (scripts/aiOpencode.sh), then re-run this step."
        log_warn "Adding the menu entry anyway; it just won't do anything until OpenCode is installed."
    fi

    cat > "$BIN_DIR/devuan-nemo-open-opencode.sh" << 'EOF'
#!/usr/bin/env bash
# Opens a terminal in the given folder running OpenCode.
set -uo pipefail
DIR="${1:-$HOME}"
exec x-terminal-emulator -e bash -c "cd \"$DIR\" && opencode; exec bash"
EOF
    chmod +x "$BIN_DIR/devuan-nemo-open-opencode.sh"

    cat > "$ACTIONS_DIR/devuan-open-opencode.nemo_action" << EOF
[Nemo Action]
Name=Open in OpenCode
Comment=Open a terminal here running the OpenCode AI agent
Exec=$BIN_DIR/devuan-nemo-open-opencode.sh %F
Icon-Name=utilities-terminal
Selection=s
Extensions=dir;
EscapeSpaces=true
EOF
    log_ok "'Open in OpenCode' added."
    INSTALLED_ANY=1
fi

if [ "$INSTALLED_ANY" -eq 1 ]; then
    echo -e "${GREEN}Nemo Actions step complete.${NC}"
    if command_exists nemo; then
        log_warn "If a new action doesn't show up in the right-click menu right away, run 'nemo -q' to restart Nemo."
    fi
else
    log_info "Nothing selected — nothing changed."
fi
