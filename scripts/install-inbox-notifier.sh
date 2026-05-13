#!/bin/bash
# install-inbox-notifier.sh
# Installs the inbox notifier as a macOS launchd agent.
#
# What this does:
#   1. Checks fswatch is installed (offers to install if not)
#   2. Copies inbox-notifier.sh to ~/Library/Application Support/eagent/
#      (must live OUTSIDE ~/Documents/ — macOS TCC blocks launchd from
#      reading scripts in Documents without Full Disk Access)
#   3. Generates a launchd plist at ~/Library/LaunchAgents/com.eagent.inbox-notifier.plist
#   4. Loads it via launchctl
#   5. Logs go to ~/Library/Logs/eagent-inbox-notifier{.log,.err.log}
#
# Idempotent — safe to re-run after editing paths or env vars.
#
# Customize via env vars:
#   EA_DATA_DIR=/custom/path bash install-inbox-notifier.sh

set -euo pipefail

EA_DATA_DIR="${EA_DATA_DIR:-$HOME/Documents/ea-data}"
INSTALL_DIR="$HOME/Library/Application Support/eagent"
WATCHER_DEST="$INSTALL_DIR/inbox-notifier.sh"
PLIST="$HOME/Library/LaunchAgents/com.eagent.inbox-notifier.plist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCHER_SRC="$SCRIPT_DIR/inbox-notifier.sh"

# 1. Check fswatch
if ! command -v fswatch >/dev/null 2>&1; then
  echo "fswatch is required. Install it first:"
  echo "  brew install fswatch"
  exit 1
fi
echo "✓ fswatch is installed ($(fswatch --version | head -1))"

# 1b. Check terminal-notifier (strongly recommended — osascript notifications are
#     often silently suppressed by macOS in launchd context)
if ! command -v terminal-notifier >/dev/null 2>&1; then
  echo "⚠ terminal-notifier not installed. Notifications via osascript are often"
  echo "  silently suppressed by macOS when fired from launchd. Strongly recommended:"
  echo "    brew install terminal-notifier"
  echo ""
  echo "  Continuing with osascript fallback — but expect to need this fix if you"
  echo "  don't see banners. Re-run this installer after installing terminal-notifier."
else
  echo "✓ terminal-notifier is installed ($(terminal-notifier -help 2>&1 | head -1 | tr -d '\n'))"
fi

# 2. Verify data folder + inbox root exists
if [ ! -d "$EA_DATA_DIR/messages/inbox" ]; then
  echo "✗ Inbox root not found: $EA_DATA_DIR/messages/inbox"
  echo ""
  echo "Create it first:"
  echo "  mkdir -p \"$EA_DATA_DIR/messages/inbox\""
  echo ""
  echo "Or set EA_DATA_DIR to point at your data folder:"
  echo "  EA_DATA_DIR=/path/to/data bash install-inbox-notifier.sh"
  exit 1
fi
echo "✓ Watching: $EA_DATA_DIR/messages/inbox"

# 3. Copy watcher to non-TCC location
mkdir -p "$INSTALL_DIR"
cp "$WATCHER_SRC" "$WATCHER_DEST"
chmod +x "$WATCHER_DEST"
echo "✓ Installed watcher: $WATCHER_DEST"

# 4. Generate plist (with the user's actual paths)
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTD/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.eagent.inbox-notifier</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${WATCHER_DEST}</string>
    </array>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>EA_DATA_DIR</key>
        <string>${EA_DATA_DIR}</string>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/eagent-inbox-notifier.log</string>

    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/eagent-inbox-notifier.err.log</string>
</dict>
</plist>
EOF
echo "✓ Wrote launchd plist: $PLIST"

# 5. (Re-)load
launchctl unload "$PLIST" 2>/dev/null || true
launchctl load -w "$PLIST"
echo "✓ Loaded launchd agent"

# 6. Verify it started cleanly
sleep 2
if launchctl list | grep -q com.eagent.inbox-notifier; then
  echo "✓ Agent is running"
else
  echo "⚠ Agent does not appear in launchctl list. Check ~/Library/Logs/eagent-inbox-notifier.err.log"
fi

cat <<EOF

Done. The notifier is running.

To test:
  bash $SCRIPT_DIR/send-message.sh ea "test notification" --from system-test

You should see a macOS banner: "📨 ea has new message: test notification"
(Then archive the test: mv \$EA_DATA_DIR/messages/inbox/ea/*test* \$EA_DATA_DIR/messages/archive/)

If you DON'T see a banner, but the daemon log shows "notifying: ..." entries:
  1. Check System Settings → Notifications → terminal-notifier (or Script Editor
     if you're on the osascript fallback) — make sure "Allow Notifications" is ON.
  2. If the app isn't in the Notifications list, run it manually once first:
       terminal-notifier -title test -message test
     macOS should prompt for permission on first use.
  3. Check that Focus / Do Not Disturb isn't active (status bar, top-right).

To stop:
  launchctl unload $PLIST

To uninstall completely:
  launchctl unload $PLIST
  rm "$PLIST"
  rm -rf "$INSTALL_DIR"
EOF
