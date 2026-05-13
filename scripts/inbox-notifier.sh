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

      # Sanitize for AppleScript embedding: backslashes and quotes
      safe_slug=$(printf '%s' "$slug" | sed 's/\\/\\\\/g; s/"/\\"/g')
      safe_title=$(printf '%s' "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')

      osascript -e "display notification \"$safe_title\" with title \"📨 $safe_slug has new message\"" >/dev/null 2>&1 || true
    done
