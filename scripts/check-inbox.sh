#!/bin/bash
# check-inbox.sh
# Reads the messages inbox for the current session and outputs a system reminder
# if there are unread messages.
#
# Used by SessionStart and PreToolUse hooks.
#
# Usage:
#   check-inbox.sh [slug]
#   If slug omitted, derived from $PWD via a-team registry.

set -euo pipefail

source "$(dirname "$0")/lib-slugify.sh"

# Derive slug
SLUG="${1:-}"
if [ -z "$SLUG" ]; then
  SLUG=$(slug_from_pwd)
fi

if [ -z "$SLUG" ]; then
  exit 0
fi

INBOX="$HOME/Documents/Tasks/messages/inbox/$SLUG"
SEEN_FILE="$HOME/Documents/Tasks/messages/.seen-${SLUG}"

if [ ! -d "$INBOX" ]; then
  exit 0
fi

# Find unread messages (newer than last-seen, or all if no seen file)
if [ -f "$SEEN_FILE" ]; then
  UNREAD=$(find "$INBOX" -name "*.md" -newer "$SEEN_FILE" 2>/dev/null)
else
  UNREAD=$(find "$INBOX" -name "*.md" 2>/dev/null)
fi

if [ -n "$UNREAD" ]; then
  COUNT=$(echo "$UNREAD" | wc -l | tr -d ' ')

  cat <<EOF
<system-reminder>
INBOX: You have $COUNT unread message(s) addressed to session '$SLUG'.

Messages are markdown files in:
  $INBOX

Read each one (use the Read tool on the full path), take action as appropriate, then move to archive:
  mv <message-path> $HOME/Documents/Tasks/messages/archive/

Do not skip messages. They are intentional handoffs from another session.

Unread messages:
EOF

  for f in $(echo "$UNREAD" | sort); do
    echo "  - $f"
  done

  echo "</system-reminder>"

  touch "$SEEN_FILE"
fi

# EA orchestrator also surfaces new triage digests since last EA session start.
# Digests are produced by EA-TRIAGE; EA folds candidate tasks into task.md.
if [ "$SLUG" = "ea" ]; then
  DIGESTS_DIR="$HOME/Documents/Tasks/inbox-digests"
  DIGEST_SEEN="$HOME/Documents/Tasks/messages/.seen-ea-digests"

  if [ -d "$DIGESTS_DIR" ]; then
    if [ -f "$DIGEST_SEEN" ]; then
      NEW_DIGESTS=$(find "$DIGESTS_DIR" -maxdepth 1 -name "*.md" -newer "$DIGEST_SEEN" 2>/dev/null)
    else
      # First run — only surface the most recent 3 to avoid flood
      NEW_DIGESTS=$(find "$DIGESTS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | sort -r | head -3)
    fi

    if [ -n "$NEW_DIGESTS" ]; then
      DCOUNT=$(echo "$NEW_DIGESTS" | wc -l | tr -d ' ')
      cat <<EOF
<system-reminder>
TRIAGE DIGESTS: $DCOUNT new digest(s) from EA-TRIAGE since you last checked.

Digests are in: $DIGESTS_DIR

Each digest has a 'Task candidates' section. Your job: read the new ones, fold candidate tasks into task.md (apply WIG / DOES / Priority Rulebook), and skim the rest for context. Then mark them seen — no need to archive, they stay as a record.

New digests:
EOF
      for f in $(echo "$NEW_DIGESTS" | sort); do
        echo "  - $f"
      done
      echo "</system-reminder>"

      touch "$DIGEST_SEEN"
    fi
  fi
fi
