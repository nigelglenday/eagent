#!/bin/bash
# kb-log.sh
# Append a change entry to kb/log.md (newest at top — feed-style).
# Email triage and other KB writers should call this whenever they update KB.
#
# Usage:
#   kb-log.sh "description" [--files file1,file2,...] [--reason "why"] [--actor "who"]
#
# Examples:
#   kb-log.sh "Added Jane Doe (intro from Conference X)" \
#     --files "kb/people/jane-doe.md" \
#     --reason "first contact, prospect lead" \
#     --actor "ea-triage"

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: kb-log.sh \"description\" [--files file1,file2,...] [--reason \"why\"] [--actor \"who\"]" >&2
  exit 1
fi

DESCRIPTION="$1"
shift

FILES=""
REASON=""
ACTOR="manual"

while [ $# -gt 0 ]; do
  case "$1" in
    --files) FILES="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

LOG="${EA_DATA_DIR:-$HOME/Documents/ea-data}/kb/log.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize log if missing
if [ ! -f "$LOG" ]; then
  cat > "$LOG" <<HEADER
# KB Change Log

*Append-only chronological record of changes to the knowledge base. Newest at top.*

*Per Karpathy llm-wiki pattern: when EA queries the KB and there's ambiguity about freshness or recent change, scan this log.*

---

HEADER
fi

# Build new entry
NEW_ENTRY=$(mktemp)
{
  echo "## $TIMESTAMP — $DESCRIPTION"
  echo ""
  echo "- **Actor:** $ACTOR"
  if [ -n "$REASON" ]; then
    echo "- **Reason:** $REASON"
  fi
  if [ -n "$FILES" ]; then
    echo "- **Files:**"
    IFS=',' read -ra FA <<< "$FILES"
    for f in "${FA[@]}"; do
      f=$(echo "$f" | /usr/bin/sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      echo "  - \`$f\`"
    done
  fi
  echo ""
} > "$NEW_ENTRY"

# Insert after the header (after first '---' line)
TMP=$(mktemp)
HEADER_END=$(/usr/bin/grep -n '^---$' "$LOG" | /usr/bin/head -1 | /usr/bin/cut -d: -f1)
if [ -z "$HEADER_END" ]; then
  # No separator found — just append
  cat "$LOG" "$NEW_ENTRY" > "$TMP"
else
  /usr/bin/head -n "$HEADER_END" "$LOG" > "$TMP"
  echo "" >> "$TMP"
  cat "$NEW_ENTRY" >> "$TMP"
  /usr/bin/tail -n +$((HEADER_END + 1)) "$LOG" >> "$TMP"
fi

mv "$TMP" "$LOG"
rm -f "$NEW_ENTRY"

echo "Logged: $DESCRIPTION"
