#!/bin/bash
# GTL Keyboard Grab Monitor v2
# Watches for ALL events that could cause key drops:
#   1. X11 keyboard grabs  → FocusOut NotifyGrab        (caught by xev)
#   2. Normal focus loss   → FocusOut NotifyNormal       (caught by xev)
#   3. Focus while grabbed → FocusOut NotifyWhileGrabbed (caught by xev)
#   4. XI2 grabs / other focus steals → active window change (caught by xprop spy)

cleanup() { kill 0 2>/dev/null; }
trap cleanup EXIT INT TERM

echo "Waiting for GT Legends window..."
for i in $(seq 1 30); do
    GTL_WIN=$(wmctrl -l 2>/dev/null | grep "GT Legends" | awk '{print $1}')
    [ -n "$GTL_WIN" ] && break
    sleep 1
done

if [ -z "$GTL_WIN" ]; then
    echo "GT Legends window not found after 30s. Is GTL running?"
    read -p "Press Enter to close..."
    exit 1
fi

echo "Monitoring GTL window: $GTL_WIN"
echo "Watching: all X11 focus events + active window changes (XI2/focus steals)"
echo "-------------------------------------------------------"

# --- Thread 1: xev on GTL window — all FocusOut modes ---
(
xev -id "$GTL_WIN" 2>&1 | while IFS= read -r line; do
    if echo "$line" | grep -q "FocusOut"; then
        MODE=$(echo "$line" | grep -o 'mode [A-Za-z]*' | awk '{print $2}')
        TS=$(date '+%H:%M:%S.%3N')
        case "$MODE" in
            NotifyGrab)
                echo ""
                echo ">>> X11 GRAB (FocusOut NotifyGrab) at $TS <<<"
                ACTIVE=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | grep -o '0x[0-9a-f]*' | head -1)
                NAME=$(xprop -id "$ACTIVE" WM_NAME 2>/dev/null | cut -d'"' -f2)
                echo "  Grabber window: $NAME ($ACTIVE)"
                echo "  All windows:"
                wmctrl -l 2>/dev/null | awk '{$1=$2=$3=""; print "    "$0}'
                echo "-------------------------------------------------------"
                ;;
            NotifyWhileGrabbed)
                echo ""
                echo ">>> FOCUS LOST WHILE GRAB ALREADY ACTIVE at $TS <<<"
                echo "-------------------------------------------------------"
                ;;
            NotifyNormal)
                echo "  [focus lost normally (NotifyNormal) at $TS — no grab]"
                ;;
        esac
    elif echo "$line" | grep -q "FocusIn" && echo "$line" | grep -q "NotifyUngrab"; then
        TS=$(date '+%H:%M:%S.%3N')
        echo "    (grab released, GTL focus restored at $TS)"
    fi
done
) &

# --- Thread 2: xprop spy — catches XI2 grabs and other active-window steals ---
(
LAST_WIN="$GTL_WIN"
xprop -spy -root _NET_ACTIVE_WINDOW 2>/dev/null | while IFS= read -r line; do
    WIN_ID=$(echo "$line" | grep -o '0x[0-9a-f]*' | head -1)
    [ -z "$WIN_ID" ] && continue
    [ "$WIN_ID" = "$LAST_WIN" ] && continue
    LAST_WIN="$WIN_ID"
    TS=$(date '+%H:%M:%S.%3N')
    if [ "$WIN_ID" != "$GTL_WIN" ]; then
        WIN_NAME=$(xprop -id "$WIN_ID" WM_NAME 2>/dev/null | cut -d'"' -f2)
        echo ""
        echo ">>> ACTIVE WINDOW CHANGED at $TS (XI2 grab or focus steal?) <<<"
        echo "  New active: $WIN_NAME ($WIN_ID)"
        echo "-------------------------------------------------------"
    else
        echo "    (GTL regained active window at $TS)"
    fi
done
) &

wait
