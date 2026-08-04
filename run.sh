#!/usr/bin/env bash
# ==========================================
# 🌿  Devuan Cinnamon Setup — Ordered Runner
# Post-install polish for a Devuan box where Cinnamon is
# already installed by the distro's own installer (task-cinnamon-desktop).
# Aims for an LMDE 7 "Gigi"-like feel — Mint-Y look, sane
# defaults, an update notifier, Timeshift — while staying
# lighter than LMDE and native to Devuan's OpenRC init.
#
# Runs setup scripts in the order defined below, asks Y/N per
# script with a default value. Same runner pattern as
# devuan-kde-setup / DebianSway.
# ==========================================

set -uo pipefail
# NOTE: intentionally not using `set -e` — one script failing (say, a
# flaky download in installFonts.sh) shouldn't abort every later step.
# Each script is expected to exit non-zero on failure so this runner
# can report it and keep going.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# --- Refuse to run as root directly ---
# Per-user state (Firefox profile, ~/.bashrc, Cinnamon/dconf settings,
# ~/.local/bin) must land in the real user's $HOME, not /root. Scripts
# call sudo themselves for the bits that need it.
if [ "$(id -u)" -eq 0 ] && [ -z "${SUDO_USER:-}" ]; then
    echo -e "${RED}Please run this as your normal user, not as root / sudo bash run.sh.${NC}"
    echo -e "${YELLOW}Each script will call sudo itself for the parts that need it.${NC}"
    exit 1
fi

# --- Distro check (Devuan or Debian; both ship /etc/debian_version) ---
if [ -f /etc/devuan_version ]; then
    echo -e "${GREEN}Devuan detected: $(cat /etc/devuan_version)${NC}"
elif [ -f /etc/debian_version ]; then
    echo -e "${YELLOW}Debian-based system detected: $(cat /etc/debian_version) (not Devuan — most of this should still work)${NC}"
else
    echo -e "${YELLOW}Warning: this toolkit targets Devuan/Debian. Your system may not be compatible.${NC}"
    read -r -p "Continue anyway? (y/N): " continue_anyway
    [[ "$continue_anyway" =~ ^[Yy]$ ]] || exit 1
fi

# --- Init system check ---
INIT="$(init_system)"
case "$INIT" in
    openrc)   echo -e "${GREEN}Init system: OpenRC (native rc-service/rc-update will be used)${NC}" ;;
    systemd)  echo -e "${YELLOW}Init system: systemd (this toolkit is written for OpenRC, but will adapt)${NC}" ;;
    sysvinit) echo -e "${YELLOW}Init system: sysvinit fallback (service/update-rc.d will be used)${NC}" ;;
esac

# --- Desktop check (best-effort, informational only — never blocks) ---
if command_exists cinnamon-session || [ -n "${XDG_CURRENT_DESKTOP:-}" ] && [[ "${XDG_CURRENT_DESKTOP,,}" == *cinnamon* ]]; then
    echo -e "${GREEN}Cinnamon detected.${NC}"
else
    echo -e "${YELLOW}Cinnamon not detected in this session — that's fine if you're running this over SSH before first login, but the theming/hotkey/mint-look steps need an active Cinnamon session to apply.${NC}"
fi

echo

# --- Ordered list: "script|description|default" ---
SCRIPTS=(
    "systemUpdate.sh|Refresh package lists and install available updates before anything else|Y"
    "addUserToGroups.sh|Add your user to input/video/render groups (needed for touchpad + GPU accel fixes)|Y"
    "cinnamonDebloat.sh|Debloat Cinnamon's default task install (Warpinator noise, redundant editors, Hexchat, etc.) toward a minimal-but-functional install|Y"
    "touchpadTrackpointFix.sh|Apply touchpad/trackpoint polling + libinput fixes|Y"
    "hardwareSupport.sh|Install WiFi/Bluetooth firmware, CPU microcode, and fwupd firmware updates|Y"
    "multimediaCodecs.sh|Install audio/video codecs + DVD playback support|Y"
    "firefoxHarden.sh|Install & harden Firefox ESR with Betterfox + privacy policies|Y"
    "installFonts.sh|Install Noto, Font Awesome, and JetBrainsMono Nerd Font|Y"
    "terminalButterbash.sh|Install ButterBash for a more functional terminal|Y"
    "fastfetchConfig.sh|Install fastfetch + curated config presets|Y"
    "usefulApps.sh|Install VLC, archive support, Nemo thumbnailers, and a few small utilities|Y"
    "mintLook.sh|Apply an LMDE-like look: Mint-Y theme/icons, wallpaper, panel layout, Nemo tweaks|Y"
    "fancyCinnamon.sh|Font, Cinnamon Maximus, Blur, gTile, panel applets, Night Light, and other video-inspired polish|Y"
    "nemoActions.sh|Add right-click actions: Compress PDF/Image, Open in VS Code/OpenCode|Y"
    "desktopEssentials.sh|Set up Flatpak, printing, GParted, and a firewall panel (Nemo/Cinnamon-native)|Y"
    "updateNotifier.sh|Install a lightweight Mint-Update-style update checker (cron-based, no systemd needed)|Y"
    "ssdTrim.sh|Enable weekly SSD TRIM via cron (safe no-op on non-SSD drives)|Y"
    "timeshiftSetup.sh|Install Timeshift for system snapshots/restore|Y"
    "hotkeys.sh|Set up Mint/ohmydebn-inspired Cinnamon keyboard shortcuts|Y"
    "aiOpencode.sh|Install OpenCode AI coding agent + hotkey + system skill file (from ohmydebn)|Y"
    "devToolsExtras.sh|(optional) Install curated dev extras: btop, eza, bat, zoxide check, Neovim+lazy.nvim, KeePassXC|N"
    "themePacks.sh|(optional) Install a few extra Cinnamon theme/icon packs + a theme-picker script (ohmydebn-inspired)|N"
    "installPhotogimp.sh|(optional) Install GIMP + PhotoGIMP's Photoshop-like layout/theme|N"
    "installVscodium.sh|(optional) Install VSCodium editor|N"
    "vscodiumDevSetup.sh|(optional) Configure VSCodium for C++/Python development|N"
    "gamingSetup.sh|(optional) Install Heroic Games Launcher / Steam / Wine|N"
    "vesktopTelegram.sh|(optional) Install Vesktop (Discord client) / Telegram|N"
)

echo -e "${BLUE}=========================================================${NC}"
echo -e "${BLUE}   Devuan Cinnamon Setup — LMDE energy, OpenRC bones${NC}"
echo -e "${BLUE}=========================================================${NC}\n"

FAILED=()
SKIPPED=()

for ENTRY in "${SCRIPTS[@]}"; do
    SCRIPT="${ENTRY%%|*}"
    REST="${ENTRY#*|}"
    DESC="${REST%%|*}"
    DEFAULT="${REST##*|}"
    SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT"

    echo -e "${YELLOW}▶ ${SCRIPT}${NC}"
    echo -e "   ${CYAN}${DESC}${NC}"

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}   ❌ Script not found: $SCRIPT_PATH${NC}\n"
        FAILED+=("$SCRIPT (missing)")
        continue
    fi

    DEFAULT=${DEFAULT^^}
    PROMPT="   ➤ Run this script? (y/N): "
    [ "$DEFAULT" == "Y" ] && PROMPT="   ➤ Run this script? (Y/n): "

    read -rp "$PROMPT" ANSWER
    ANSWER=${ANSWER:-$DEFAULT}
    echo

    case "${ANSWER^^}" in
        Y)
            echo -e "${GREEN}   ✅ Running $SCRIPT...${NC}"
            if bash "$SCRIPT_PATH"; then
                echo -e "${GREEN}   ✅ Done: $SCRIPT${NC}\n"
            else
                echo -e "${RED}   ❌ $SCRIPT exited with an error (continuing with the rest)${NC}\n"
                FAILED+=("$SCRIPT")
            fi
            ;;
        *)
            echo -e "${YELLOW}   ⚠ Skipped: $SCRIPT${NC}\n"
            SKIPPED+=("$SCRIPT")
            ;;
    esac
done

echo -e "${BLUE}=========================================================${NC}"
echo -e "${BLUE}   🏁 All tasks processed.${NC}"
echo -e "${BLUE}=========================================================${NC}"

if [ "${#SKIPPED[@]}" -gt 0 ]; then
    echo -e "${YELLOW}Skipped: ${SKIPPED[*]}${NC}"
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
    echo -e "${RED}Failed:  ${FAILED[*]}${NC}"
    echo -e "${YELLOW}Re-run individual scripts directly with: bash scripts/<name>.sh${NC}"
    exit 1
fi

echo -e "${GREEN}Done. A logout/reboot is recommended (group membership, theme, and panel changes all benefit from a fresh session).${NC}"
