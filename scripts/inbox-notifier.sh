#!/bin/bash
# inbox-notifier.sh
# Background daemon that watches messages/inbox/ for new files and fires a
# macOS notification when one lands. Solves the "session open + idle" gap —
# the user sees a banner the moment a message arrives, clicks into the
# session, and the existing SessionStart/PreToolUse hook surfaces the
# message normally.
#
# Designed to run via launchd. Install with: bash install-inbox-notifier.sh
#
# Usage (direct, for testing):
#   bash inbox-notifier.sh                    # uses $EA_DATA_DIR or default
#   EA_DATA_DIR=/custom/path bash inbox-notifier.sh
#
# Requires: fswatch (brew install fswatch)

set -euo pipefail

EA_DATA_DIR="${EA_DATA_DIR:-$HOME/Documents/ea-data}"
INBOX_ROOT="$EA_DATA_DIR/messages/inbox"

if ! command -v fswatch >/dev/null 2>&1; then
  echo "fswatch not installed. Install with: brew install fswatch" >&2
  exit 1
fi

if [ ! -d "$INBOX_ROOT" ]; then
  echo "Inbox root not found: $INBOX_ROOT" >&2
  echo "Create it first, or set EA_DATA_DIR to point at your data folder." >&2
  exit 1
fi

# Watch options:
#   -0                NUL-delimited output (handles paths with newlines/spaces)
#   --event Created   only fire on file creation (skip metadata updates, deletes)
#   --extended        enable extended regex
#   --include         only forward paths matching the regex
#   --exclude .*      default-exclude everything else
fswatch \
  -0 \
  --event Created \
  --extended \
  --include '/messages/inbox/[^/]+/[^/]+\.md$' \
  --exclude '.*' \
  "$INBOX_ROOT" \
  | while IFS= read -r -d '' path; do
      slug=$(basename "$(dirname "$path")")
      filename=$(basename "$path" .md)
      # Strip the timestamp prefix (YYYY-MM-DD-HHMM-) to get a readable title
      title=$(echo "$filename" | sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{4\}-//' | tr '-' ' ')

      # Sanitize for embedding in shell / AppleScript args: backslashes and quotes
      safe_slug=$(printf '%s' "$slug" | sed 's/\\/\\\\/g; s/"/\\"/g')
      safe_title=$(printf '%s' "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')

      echo "$(date '+%Y-%m-%dT%H:%M:%S') notifying: $slug / $title" >&2

      # Prefer terminal-notifier (gets its own notification permission, more reliable
      # than osascript which inherits Script Editor's permission and is often silently
      # suppressed by macOS in launchd context). Fall back to osascript if not installed.
      if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier \
          -title "📨 $safe_slug has new message" \
          -message "$safe_title" \
          -group "eagent-inbox-$safe_slug" \
          2>&1 >&2 || true
      else
        osascript -e "display notification \"$safe_title\" with title \"📨 $safe_slug has new message\"" 2>&1 >&2 || true
      fi
    done
