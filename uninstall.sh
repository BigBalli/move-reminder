#!/usr/bin/env bash
# move-reminder uninstaller.
#   curl -fsSL https://raw.githubusercontent.com/BigBalli/move-reminder/main/uninstall.sh | bash
set -euo pipefail

APP_NAME="move-reminder"
APP_ID="com.bigballi.move-reminder"
INSTALL_DIR="$HOME/Library/Application Support/$APP_NAME"
PLIST="$HOME/Library/LaunchAgents/$APP_ID.plist"

launchctl bootout "gui/$(id -u)/$APP_ID" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$INSTALL_DIR"

printf '\033[1;34m==>\033[0m move-reminder uninstalled.\n'
