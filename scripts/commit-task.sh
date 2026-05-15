#!/usr/bin/env bash
# commit-task.sh: commit task.md (and worker state files) with a tagged message.
#
# Usage:
#   bash scripts/commit-task.sh "triage: cycle 2026-05-14 04pm: 7 replies, 2 removals"
#
# Intended to be called by the triage worker after every write to task.md.
# Per-write commits give intra-day git history; pair with a daily snapshot
# cron for a safety net.
#
# Operates on the data dir at $EA_DATA_DIR (defaults to current working dir
# if unset — typical setup is to run from the data dir).
#
# No-ops cleanly if nothing has changed.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 \"<commit message>\"" >&2
  exit 1
fi

MSG="$1"
REPO="${EA_DATA_DIR:-$PWD}"
cd "$REPO"

# Files the worker may have touched in this write.
FILES=(task.md .ea-task-snapshot.md .ea-task-state.json)

# Exit cleanly if none of the tracked files have changes vs HEAD and there
# are no new untracked variants either.
if git diff --quiet HEAD -- "${FILES[@]}" 2>/dev/null \
   && ! git ls-files --others --exclude-standard -- "${FILES[@]}" | grep -q .; then
  echo "No changes to commit"
  exit 0
fi

for f in "${FILES[@]}"; do
  if [[ -e "$f" ]]; then
    git add "$f"
  fi
done

# Use a non-personal identity for worker-driven commits so the audit trail
# clearly marks which actor wrote what.
git -c user.email="ea-triage@local" -c user.name="EA-Triage" commit -q -m "$MSG"
echo "Committed: $MSG"
