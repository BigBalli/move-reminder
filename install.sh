#!/usr/bin/env bash
# move-reminder installer.
# Works from a cloned repo or piped from curl:
#   curl -fsSL https://raw.githubusercontent.com/BigBalli/move-reminder/main/install.sh | bash
set -euo pipefail

APP_NAME="move-reminder"
APP_ID="com.bigballi.move-reminder"
INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_AGENTS/$APP_ID.plist"
REPO_RAW="https://raw.githubusercontent.com/BigBalli/move-reminder/main"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || die "move-reminder is macOS-only."

# Copy from the local checkout if present, otherwise download from the repo.
fetch() { # <repo-relative-path> <destination>
  local rel="$1" dest="$2"
  if [ -n "${SCRIPT_DIR:-}" ] && [ -f "$SCRIPT_DIR/$rel" ]; then
    cp "$SCRIPT_DIR/$rel" "$dest"
  else
    curl -fsSL "$REPO_RAW/$rel" -o "$dest" || die "could not fetch $rel"
  fi
}

say "Installing $APP_NAME to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$LAUNCH_AGENTS"

fetch "src/move-reminder.sh" "$INSTALL_DIR/move-reminder.sh"
chmod +x "$INSTALL_DIR/move-reminder.sh"

# Compile the full-screen overlay if Swift is available; otherwise the script
# falls back to a simple notification dialog on its own.
if command -v swiftc >/dev/null 2>&1; then
  say "Compiling the full-screen overlay…"
  tmp="$(mktemp -t MoveReminderOverlay)" && mv "$tmp" "$tmp.swift" && tmp="$tmp.swift"
  fetch "src/MoveReminderOverlay.swift" "$tmp"
  if swiftc -O "$tmp" -o "$INSTALL_DIR/move-reminder-overlay" -framework Cocoa 2>/dev/null; then
    say "Overlay built."
  else
    warn "Overlay failed to compile — the simple dialog will be used instead."
  fi
  rm -f "$tmp"
else
  warn "swiftc not found. Install Xcode Command Line Tools for the full-screen overlay:"
  warn "    xcode-select --install"
  warn "For now, a simple notification dialog will be used."
fi

say "Registering the LaunchAgent ($APP_ID)…"
cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$APP_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$INSTALL_DIR/move-reminder.sh</string>
  </array>
  <key>StartInterval</key>
  <integer>300</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$INSTALL_DIR/log</string>
  <key>StandardErrorPath</key>
  <string>$INSTALL_DIR/log</string>
</dict>
</plist>
PLIST_EOF

launchctl bootout "gui/$(id -u)/$APP_ID" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

say "Done. Reminders fire every day 9am–6pm, ~1 hour after each wake."
echo
echo "  Try it now:   bash \"$INSTALL_DIR/move-reminder.sh\" --test"
echo "  Customize:    edit \"$INSTALL_DIR/move-reminder.sh\"  (hours, interval, break length)"
echo "  Uninstall:    curl -fsSL $REPO_RAW/uninstall.sh | bash"
