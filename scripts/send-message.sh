#!/bin/bash
# send-message.sh
# Drop a message into another session's inbox.
#
# Usage:
#   send-message.sh <to-session> "message body" [options]
#
# Options:
#   --from <session>       Sender session name (default: derived from $PWD)
#   --priority <level>     urgent | normal | fyi (default: normal)
#   --title <slug>         Short slug for filename (default: derived from body)
#   --notify               Fire a macOS notification when sent
#   --related <refs>       Comma-separated refs (issue numbers, PRs, etc.)
#
# Examples:
#   send-message.sh sidekick "Look at PR #123 — mobile layout regression"
#   send-message.sh worker-b "Customer X wants to upgrade — pricing convo needed" --priority urgent --notify
#   send-message.sh project-y "Counterparty replied — see thread" --related "deal-y-2026"

set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: send-message.sh <to-session> \"message body\" [options]" >&2
  exit 1
fi

TO="$1"
BODY="$2"
shift 2

# Defaults
FROM=""
PRIORITY="normal"
TITLE_SLUG=""
NOTIFY=0
RELATED=""

# Parse options
while [ $# -gt 0 ]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --priority) PRIORITY="$2"; shift 2 ;;
    --title) TITLE_SLUG="$2"; shift 2 ;;
    --notify) NOTIFY=1; shift ;;
    --related) RELATED="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Derive sender from PWD if not given.
# Best path: look up the slug via the a-team registry (uses lib-slugify if sourced).
# Fallback: use the basename of $PWD as the slug.
if [ -z "$FROM" ]; then
  if declare -f slug_from_pwd >/dev/null 2>&1; then
    FROM=$(slug_from_pwd)
  fi
  if [ -z "$FROM" ]; then
    FROM=$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/--*/-/g; s/^-//; s/-$//')
  fi
  if [ -z "$FROM" ]; then
    FROM="unknown"
  fi
fi

# Derive title slug from body if not given (first 6 words, lowercased, hyphenated)
if [ -z "$TITLE_SLUG" ]; then
  TITLE_SLUG=$(echo "$BODY" | head -c 80 | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c 1-50)
  if [ -z "$TITLE_SLUG" ]; then
    TITLE_SLUG="message"
  fi
fi

# Build paths. EA_DATA_DIR can be set to override the default location.
EA_DATA_DIR="${EA_DATA_DIR:-$HOME/Documents/ea-data}"
INBOX_DIR="$EA_DATA_DIR/messages/inbox/$TO"
TIMESTAMP=$(date +%Y-%m-%d-%H%M)
FILENAME="${TIMESTAMP}-${TITLE_SLUG}.md"
FILEPATH="$INBOX_DIR/$FILENAME"

# Ensure inbox exists
mkdir -p "$INBOX_DIR"

# Build the message file
SENT_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

{
  echo "---"
  echo "from: $FROM"
  echo "to: $TO"
  echo "sent_at: $SENT_AT"
  echo "priority: $PRIORITY"
  if [ -n "$RELATED" ]; then
    echo "related: [$RELATED]"
  fi
  echo "---"
  echo ""
  echo "$BODY"
} > "$FILEPATH"

echo "Message queued: $FILEPATH"

# Optional notification
if [ "$NOTIFY" -eq 1 ]; then
  TITLE="EA → $TO"
  if [ "$PRIORITY" = "urgent" ]; then
    TITLE="🔴 EA → $TO (urgent)"
  fi
  # Truncate body to 100 chars for notification
  PREVIEW=$(echo "$BODY" | head -c 100)
  osascript -e "display notification \"$PREVIEW\" with title \"$TITLE\""
fi
