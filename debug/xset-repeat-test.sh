#!/bin/bash
# GTL Key Repeat Test
# Tests whether disabling X11 key repeat eliminates the occasional key drop bug.
#
# Background: Wine filters fake auto-repeat KeyRelease events by peeking ahead
# in the X11 event queue. Under load, this peek can misfire and swallow a real
# keypress, making the key appear dead until pressed again. Disabling X11 key
# repeat removes that filtering entirely and tells us if this is the cause.

echo "========================================="
echo "  GTL Key Repeat Test"
echo "========================================="
echo ""
echo "This disables X11 key repeat for the duration of your gaming session."
echo ""
echo "What to watch for:"
echo "  - If key drops STOP  → auto-repeat filtering in Wine is the culprit"
echo "  - If key drops CONTINUE → different cause, need to investigate further"
echo ""
echo "Disabling X11 key repeat now..."
xset r off
echo "Done. Key repeat is OFF."
echo ""
echo "Launch GT Legends and play normally."
echo "Try to reproduce the key drop (e.g. press arrow keys repeatedly mid-race)."
echo ""
read -p "Type 'done' when finished gaming and press Enter: " INPUT
echo ""
echo "Restoring X11 key repeat..."
xset r on
echo "Done. Key repeat is ON again."
echo ""
echo "========================================="
echo "  Result?"
echo "========================================="
echo ""
echo "  Drops stopped  → the launcher will be updated to always run"
echo "                   with key repeat off during GTL sessions."
echo ""
echo "  Drops continued → auto-repeat ruled out. Next step: WINEDEBUG=+key"
echo "                    to trace whether Wine receives the keypresses at all."
echo ""
read -p "Press Enter to close..."
