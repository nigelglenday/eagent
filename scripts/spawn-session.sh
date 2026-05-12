#!/bin/bash
# spawn-session.sh
# Wraps a-team to spawn a Claude Code session for an existing or new agent.
# Optionally queues an initial prompt as an inbox message before launch, so the
# receiving session's SessionStart hook surfaces it.
#
# Usage:
#   spawn-session.sh <slug-or-name> [initial prompt]
#   spawn-session.sh new <slug> <path> [--ephemeral] [--category <cat>] [initial prompt]
#
# Examples:
#   spawn-session.sh worker-a
#   spawn-session.sh worker-a "look at PR #123"
#   spawn-session.sh new project-x $HOME/Documents/project-x --ephemeral "kick off the project — see brief in folder"

set -euo pipefail

source "$(dirname "$0")/lib-slugify.sh"

if [ $# -lt 1 ]; then
  cat <<EOF
Usage:
  spawn-session.sh <slug-or-name> [initial prompt]
  spawn-session.sh new <slug> <path> [--ephemeral] [--category <cat>] [initial prompt]

Existing agents (a-team registry):
EOF
  bash "$(dirname "$0")/list-agents.sh" | sed 's/^/  /'
  exit 1
fi

# === new agent path ===
if [ "$1" = "new" ]; then
  shift
  if [ $# -lt 2 ]; then
    echo "Usage: spawn-session.sh new <slug> <path> [--ephemeral] [--category <cat>] [initial prompt]" >&2
    exit 1
  fi
  SLUG="$1"
  PATH_ARG="$2"
  shift 2

  KIND="persistent"
  CATEGORY=""
  PROMPT=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --ephemeral) KIND="ephemeral"; shift ;;
      --category) CATEGORY="$2"; shift 2 ;;
      *) PROMPT="$1"; shift ;;
    esac
  done

  if [ ! -d "$PATH_ARG" ]; then
    echo "Folder does not exist: $PATH_ARG" >&2
    echo "(Create the folder first if this is a new workstream.)" >&2
    exit 1
  fi

  # Register with a-team
  echo "Registering agent '$SLUG' (kind: $KIND) in a-team..."
  a-team new "$SLUG" "$PATH_ARG"

  # Edit TOML to set kind/category (a-team new doesn't take these flags)
  if [ "$KIND" != "persistent" ] || [ -n "$CATEGORY" ]; then
    python3 <<EOF
import re
with open("$ATEAM_TOML") as f:
    text = f.read()
# Find the just-added agent block and amend it
slug = "$SLUG"
kind = "$KIND"
category = "$CATEGORY"
pattern = re.compile(r'(\[\[agent\]\]\nname = "' + re.escape(slug) + r'"\npath = "[^"]+"\n?)', re.MULTILINE)
m = pattern.search(text)
if m:
    block = m.group(1).rstrip("\n")
    new_block = block + f'\nkind = "{kind}"\n'
    if category:
        new_block += f'category = "{category}"\n'
    text = text[:m.start()] + new_block + text[m.end():]
    with open("$ATEAM_TOML", "w") as f:
        f.write(text)
EOF
  fi

  TARGET_SLUG=$(slugify "$SLUG")

  # Wire inbox infrastructure on creation (idempotent)
  bash "$(dirname "$0")/wire-inbox.sh" --slug "$TARGET_SLUG" --path "$PATH_ARG" || true
else
  # === existing agent path ===
  INPUT="$1"
  shift
  PROMPT="${1:-}"
  TARGET_SLUG=$(slugify "$INPUT")
fi

# Queue initial prompt as inbox message if given
if [ -n "$PROMPT" ]; then
  bash "$(dirname "$0")/send-message.sh" "$TARGET_SLUG" "$PROMPT" --priority urgent
fi

# Launch via a-team (which handles the Ghostty + cd + claude --continue)
echo "Launching agent via a-team..."
a-team "$TARGET_SLUG"

if [ -n "$PROMPT" ]; then
  echo "Initial prompt queued in inbox; SessionStart hook will surface it on launch."
fi
