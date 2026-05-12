#!/bin/bash
# email-triage.sh
# Manual trigger for the email triage skill.
#
# Usage: bash scripts/email-triage.sh
#
# This is a thin wrapper. The actual triage logic is in:
#   prompts/email-triage.md
#
# Production cadence: run via /loop in a dedicated TRIAGE Ghostty window:
#   cd ~/Documents/Tasks
#   claude
#   > /loop /triage           (or just paste the prompt)
#
# Manual trigger: open a Claude Code session in Documents/Tasks/ and paste the
# contents of prompts/email-triage.md. This script is here as a reminder of the
# pattern, not as a headless executor (Claude Code headless from a script is
# fragile — keep triage interactive for v1).

set -euo pipefail

PROMPT_FILE="$(dirname "$0")/../prompts/email-triage.md"
DIGEST_DIR="$(dirname "$0")/../inbox-digests"

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Error: triage prompt not found at $PROMPT_FILE"
  exit 1
fi

mkdir -p "$DIGEST_DIR"

cat <<EOF
Email triage — manual trigger.

To run the triage:
  1. Open a Claude Code session in this folder (cd ~/Documents/Tasks && claude)
  2. Either:
     a) Run /loop and paste the triage prompt
     b) Paste the contents of $PROMPT_FILE directly
     c) (When wired) run /triage slash command

Triage prompt: $PROMPT_FILE
Digests will land in: $DIGEST_DIR

Why no headless mode? Triage benefits from staying conversational and
interruptible. /loop in an interactive session keeps cache warm and lets
you steer mid-cycle.

Last 3 digests:
EOF

ls -1t "$DIGEST_DIR"/*.md 2>/dev/null | head -3 || echo "  (no digests yet)"
