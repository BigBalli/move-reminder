#!/bin/bash
# move-reminder — nudge yourself to stand up and move, once an hour.
#
# The reminder is anchored to your Mac's last wake time (kern.waketime), not to
# the clock. Open the lid at 9:17 and the first reminder lands at 10:17, the
# next at 11:17, and so on — but only while the clock is inside the active
# window below. Reopening the laptop (a new wake) resets the 1-hour timer.
#
# Installed and run by a LaunchAgent that polls every few minutes.

# ── Config ────────────────────────────────────────────────────────────────
START_HOUR=9        # active window start, inclusive (24h)
END_HOUR=18         # active window end, exclusive (24h) — 18 = 6pm
INTERVAL=3600       # seconds between reminders (3600 = 1 hour)
BREAK_SECONDS=120   # length of the break countdown shown in the overlay
# ──────────────────────────────────────────────────────────────────────────

STATE_DIR="$HOME/Library/Application Support/move-reminder"
STATE_FILE="$STATE_DIR/state"
OVERLAY="$STATE_DIR/move-reminder-overlay"

notify() {
  /usr/bin/afplay /System/Library/Sounds/Funk.aiff >/dev/null 2>&1 &
  if [ -x "$OVERLAY" ]; then
    "$OVERLAY" "$BREAK_SECONDS" >/dev/null 2>&1
  else
    /usr/bin/osascript -e 'display dialog "Stand up and move around for a few minutes." with title "Move" buttons {"Done"} default button "Done" with icon note giving up after 90' >/dev/null 2>&1
  fi
}

# --test: show the reminder immediately and exit (for verifying presentation).
if [ "$1" = "--test" ]; then notify; exit 0; fi

mkdir -p "$STATE_DIR"

waketime=$(sysctl -n kern.waketime | awk '{print $4}' | tr -d ',')
now=$(date +%s)
hour=$((10#$(date +%H)))

anchor=0; last_index=0
[ -f "$STATE_FILE" ] && read -r anchor last_index < "$STATE_FILE"

# Reset the timer whenever the machine has woken since the stored anchor.
if [ "$waketime" != "$anchor" ]; then
  anchor=$waketime
  last_index=0
fi

elapsed=$(( now - anchor ))
[ "$elapsed" -lt 0 ] && elapsed=0
target_index=$(( elapsed / INTERVAL ))

if [ "$target_index" -gt "$last_index" ]; then
  last_index=$target_index            # advance even if outside window, so we don't backfire
  if [ "$hour" -ge "$START_HOUR" ] && [ "$hour" -lt "$END_HOUR" ]; then
    notify
  fi
fi

printf '%s %s\n' "$anchor" "$last_index" > "$STATE_FILE"
