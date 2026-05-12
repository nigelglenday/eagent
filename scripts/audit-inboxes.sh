#!/bin/bash
# audit-inboxes.sh
# Walk the a-team registry and check each agent for inbox infrastructure:
#   1. .claude/settings.json with check-inbox hook
#   2. messages/inbox/<slug>/ folder
#   3. "Inter-session inbox" section in CLAUDE.md
#
# Usage:
#   audit-inboxes.sh           # report only
#   audit-inboxes.sh --fix     # auto-wire any agent missing infrastructure
#   audit-inboxes.sh --fix --skip ephemeral   # skip ephemeral agents when fixing
#
# Exit code 0 = all wired (or all fixed); 1 = gaps remain after run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-slugify.sh"

TASKS_ROOT="$HOME/Documents/Tasks"

FIX=0
SKIP_EPHEMERAL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX=1; shift ;;
    --skip) [ "$2" = "ephemeral" ] && SKIP_EPHEMERAL=1; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Always treat EA orchestrator and EA Triage specially — they're hand-wired in code/ea/
SPECIAL_SLUGS=("ea" "ea-triage")

GAPS=0
FIXED=0

printf "%-25s %-12s %-9s %-9s %-9s  %s\n" "SLUG" "KIND" "SETTINGS" "INBOX" "CLAUDE" "PATH"
printf "%-25s %-12s %-9s %-9s %-9s  %s\n" "-----" "----" "--------" "-----" "------" "----"

while IFS='|' read -r slug name path kind category; do
  if [ "$SKIP_EPHEMERAL" -eq 1 ] && [ "$kind" = "ephemeral" ]; then
    continue
  fi

  # Status check
  settings_status="✗"
  inbox_status="✗"
  claude_status="✗"

  if [ -d "$path" ]; then
    if [ -f "$path/.claude/settings.json" ] && grep -q "check-inbox.sh $slug" "$path/.claude/settings.json" 2>/dev/null; then
      settings_status="✓"
    fi
    if [ -f "$path/.claude/CLAUDE.md" ] && grep -q "Inter-session inbox" "$path/.claude/CLAUDE.md" 2>/dev/null; then
      claude_status="✓"
    elif [ ! -f "$path/.claude/CLAUDE.md" ]; then
      claude_status="—"
    fi
  else
    settings_status="(path missing)"
    claude_status="(path missing)"
  fi

  if [ -d "$TASKS_ROOT/messages/inbox/$slug" ]; then
    inbox_status="✓"
  fi

  # Print row
  printf "%-25s %-12s %-9s %-9s %-9s  %s\n" "$slug" "$kind" "$settings_status" "$inbox_status" "$claude_status" "$path"

  # Count gaps
  if [ "$settings_status" != "✓" ] || [ "$inbox_status" != "✓" ] || { [ "$claude_status" != "✓" ] && [ "$claude_status" != "—" ]; }; then
    GAPS=$((GAPS + 1))

    if [ "$FIX" -eq 1 ] && [ -d "$path" ]; then
      echo "  → fixing $slug..."
      if bash "$SCRIPT_DIR/wire-inbox.sh" --slug "$slug" --path "$path" 2>&1 | sed 's/^/    /'; then
        FIXED=$((FIXED + 1))
      fi
    fi
  fi
done < <(ateam_agents)

echo ""
echo "Special-cased (hand-wired in code/ea/):"
for s in "${SPECIAL_SLUGS[@]}"; do
  printf "  %-25s  (managed in $HOME/code/ea/)\n" "$s"
done

echo ""
if [ "$GAPS" -eq 0 ]; then
  echo "✓ All a-team agents wired."
  exit 0
elif [ "$FIX" -eq 1 ]; then
  echo "Fixed $FIXED of $GAPS gaps. Run again with --fix to retry any leftovers."
  exit 0
else
  echo "$GAPS gap(s). Re-run with --fix to auto-wire."
  exit 1
fi
