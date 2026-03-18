#!/bin/bash
# GT Legends + ABB Launcher
# A menu for launching all GTL tools correctly on Linux.
#
# Setup: fill in the configuration block below, then run this script
# or use the GTL-Launcher.desktop shortcut.

# ── Configuration ──────────────────────────────────────────────────────────────

# Path to the wine-10.20 runner (used for AutoUpdater, GTLConfig, LowGuard)
WINEDIR="$HOME/.local/share/lutris/runners/wine/wine-10.20-staging-amd64"

# Path to your Wine prefix
export WINEPREFIX="$HOME/Games/GTLegends-Prefix"

# Your Linux username (used to find the AutoUpdater script inside the prefix)
LINUX_USER="$USER"

# Lutris game ID for GT Legends.
# Find it in Lutris: right-click GT Legends → Configure — the ID is shown in the
# window title bar (e.g. "Configure GT Legends (2)").
LUTRIS_GAME_ID=2

# ZeroTier network ID for private races (optional — leave blank if not using ZeroTier)
ZT_NETWORK_ID=""

# ── End of configuration ───────────────────────────────────────────────────────

export LD_LIBRARY_PATH="${WINEDIR}/lib:${WINEDIR}/lib/wine/i386-unix:${WINEDIR}/lib/wine/x86_64-unix:${LD_LIBRARY_PATH}"

# Check ZeroTier status
if systemctl is-active --quiet zerotier-one; then
    ZT_STATUS="● ZeroTier: Connected"
else
    ZT_STATUS="○ ZeroTier: Disconnected"
fi

CHOICE=$(zenity --list \
    --title="GT Legends" \
    --text="Select what to launch:        ${ZT_STATUS}" \
    --column="Launch" \
    --column="Description" \
    --hide-column=2 \
    --print-column=1 \
    --height=300 \
    --width=440 \
    "GT Legends" "Play via Lutris (DXVK, full performance)" \
    "AutoUpdater" "Check for ABB car/track updates" \
    "GTLConfig" "Change resolution and graphics settings" \
    "LowGuard" "Anti-cheat client (launches GTL)" \
    "ZeroTier: Connect" "Start the gaming VPN" \
    "ZeroTier: Disconnect" "Stop the gaming VPN" \
    "ZeroTier: Add Friend" "Instructions to invite a friend" \
    2>/dev/null)

[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
    "GT Legends")
        # CPU affinity: pin GTL to cores 2+3 (0-indexed) after launch.
        # Avoids CPU 0 (handles system IRQs on Linux). Cores 2+3 are two
        # independent physical cores — main game loop uses one, background
        # threads use the other. Safe default for any ≥4-core CPU.
        # To change: edit the "2,3" in the taskset line below.
        lutris "lutris:rungameid/${LUTRIS_GAME_ID}" &
        TIMEOUT=30
        while [ $TIMEOUT -gt 0 ]; do
            GTL_PID=$(pgrep -i "GTL.exe" 2>/dev/null)
            [ -n "$GTL_PID" ] && break
            sleep 1
            TIMEOUT=$((TIMEOUT - 1))
        done
        if [ -n "$GTL_PID" ]; then
            taskset -cp 2,3 "$GTL_PID" >/dev/null 2>&1
        fi
        ;;
    "AutoUpdater")
        # Kill wineserver and strip the WineDesktop key before launching.
        # This prevents a blue fullscreen background that appears when
        # the AutoUpdater is launched after GTL has been run via Lutris.
        WINEPREFIX="$WINEPREFIX" "${WINEDIR}/bin/wineserver" -k 2>/dev/null
        sleep 1
        sed -i '/^"Desktop"="WineDesktop"$/d' "${WINEPREFIX}/user.reg"
        "${WINEDIR}/bin/wine" \
            "${WINEPREFIX}/drive_c/Python27/python.exe" \
            "${WINEPREFIX}/drive_c/users/${LINUX_USER}/Documents/Bierbuden/altbierbude_en.pyw"
        ;;
    "GTLConfig")
        cd "${WINEPREFIX}/drive_c/GTL"
        "${WINEDIR}/bin/wine" GTLConfig.exe
        ;;
    "LowGuard")
        cd "${WINEPREFIX}/drive_c/GTL"
        "${WINEDIR}/bin/wine" lowGuard.exe
        ;;
    "ZeroTier: Connect")
        sudo systemctl start zerotier-one
        ZT_IP=$(ip addr show zt+ 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        zenity --info --title="ZeroTier" \
            --text="Connected to gaming VPN.\n\nNetwork: ${ZT_NETWORK_ID:-[not configured]}\nYour IP: ${ZT_IP:-[detecting...]}" \
            --width=300 2>/dev/null
        ;;
    "ZeroTier: Disconnect")
        sudo systemctl stop zerotier-one
        zenity --info --title="ZeroTier" \
            --text="Disconnected from gaming VPN." \
            --width=300 2>/dev/null
        ;;
    "ZeroTier: Add Friend")
        zenity --info \
            --title="ZeroTier — Add a Friend" \
            --text="To add a friend to your gaming VPN:\n\nNetwork ID:  ${ZT_NETWORK_ID:-[set ZT_NETWORK_ID in launch-gtl.sh]}\n\nOn Windows:\n 1. Download ZeroTier from zerotier.com/download\n 2. Right-click tray icon → Join New Network\n 3. Enter the Network ID above\n\nOn Linux/macOS:\n 1. Install ZeroTier\n 2. Run: sudo zerotier-cli join [Network ID]\n\nAfter they join:\n • Go to my.zerotier.com → your network → Members\n • Tick the Auth checkbox next to their device" \
            --width=440 2>/dev/null
        ;;
esac
