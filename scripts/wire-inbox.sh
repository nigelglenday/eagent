#!/bin/bash
# wire-inbox.sh
# Idempotently wires inter-session inbox infrastructure for an a-team agent:
#   1. Creates .claude/settings.json with SessionStart + PreToolUse hooks
#   2. Creates the inbox folder at messages/inbox/<slug>/
#   3. Prepends the "Inter-session inbox" boilerplate to the agent's CLAUDE.md
#      (only if not already present)
#
# Usage:
#   wire-inbox.sh <slug>            # look up path from a-team registry
#   wire-inbox.sh --path <path>     # explicit path, derive slug from a-team
#   wire-inbox.sh --slug <slug> --path <path>  # both explicit
#
# Safe to run multiple times — idempotent. Reports what changed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib-slugify.sh"

TASKS_ROOT="$HOME/Documents/Tasks"
TEMPLATE="$SCRIPT_DIR/templates/inbox-claude-section.md"

SLUG=""
AGENT_PATH=""

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --path) AGENT_PATH="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      if [ -z "$SLUG" ]; then
        SLUG="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$SLUG" ] && [ -z "$AGENT_PATH" ]; then
  echo "Usage: wire-inbox.sh <slug> | --path <path> | --slug <slug> --path <path>" >&2
  exit 1
fi

# Derive slug from path if missing
if [ -z "$SLUG" ] && [ -n "$AGENT_PATH" ]; then
  SLUG=$(slug_from_path "$AGENT_PATH")
  if [ -z "$SLUG" ]; then
    echo "Could not derive slug from $AGENT_PATH (not in a-team registry)" >&2
    exit 1
  fi
fi

# Derive path from slug if missing
if [ -z "$AGENT_PATH" ]; then
  AGENT_PATH=$(path_from_slug "$SLUG")
  if [ -z "$AGENT_PATH" ]; then
    echo "Slug '$SLUG' not found in a-team registry" >&2
    echo "Add it first with: a-team new \"<Name>\" <path>" >&2
    exit 1
  fi
fi

if [ ! -d "$AGENT_PATH" ]; then
  echo "Agent path does not exist: $AGENT_PATH" >&2
  exit 1
fi

echo "Wiring inbox for slug='$SLUG' at $AGENT_PATH"

CHANGED=0

# 1. Inbox folder
INBOX="$TASKS_ROOT/messages/inbox/$SLUG"
if [ ! -d "$INBOX" ]; then
  mkdir -p "$INBOX"
  echo "  ✓ Created inbox folder: $INBOX"
  CHANGED=1
else
  echo "  · Inbox folder already exists"
fi

# 2. settings.json
SETTINGS_DIR="$AGENT_PATH/.claude"
SETTINGS="$SETTINGS_DIR/settings.json"
mkdir -p "$SETTINGS_DIR"

if [ ! -f "$SETTINGS" ]; then
  cat > "$SETTINGS" <<EOF
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash $TASKS_ROOT/scripts/check-inbox.sh $SLUG"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash $TASKS_ROOT/scripts/check-inbox.sh $SLUG"
          }
        ]
      }
    ]
  }
}
EOF
  echo "  ✓ Wrote $SETTINGS"
  CHANGED=1
else
  # Check whether existing settings.json has our hook
  if grep -q "check-inbox.sh $SLUG" "$SETTINGS" 2>/dev/null; then
    echo "  · settings.json already has check-inbox hook"
  else
    echo "  ⚠ settings.json exists but lacks check-inbox hook for '$SLUG'"
    echo "    Inspect manually: $SETTINGS"
    echo "    Add SessionStart + PreToolUse hooks calling: bash $TASKS_ROOT/scripts/check-inbox.sh $SLUG"
  fi
fi

# 3. CLAUDE.md boilerplate
CLAUDE_MD="$AGENT_PATH/.claude/CLAUDE.md"

if [ ! -f "$TEMPLATE" ]; then
  echo "  ⚠ Template not found at $TEMPLATE — skipping CLAUDE.md edit"
elif [ ! -f "$CLAUDE_MD" ]; then
  # Create a stub CLAUDE.md with the boilerplate at the top
  RENDERED=$(sed "s/__SLUG__/$SLUG/g" "$TEMPLATE")
  cat > "$CLAUDE_MD" <<EOF
# $SLUG

(Auto-generated CLAUDE.md. Replace this with the agent's actual brain.)

---

$RENDERED
EOF
  echo "  ✓ Created stub $CLAUDE_MD with inbox boilerplate"
  CHANGED=1
else
  if grep -q "Inter-session inbox" "$CLAUDE_MD" 2>/dev/null; then
    echo "  · CLAUDE.md already has inbox section"
  else
    # Render the template (slug substitution), then inject right after the first H1 + its blank line.
    # Done in Python to avoid awk's multi-line-variable issues.
    RENDERED_FILE=$(mktemp)
    sed "s/__SLUG__/$SLUG/g" "$TEMPLATE" > "$RENDERED_FILE"
    python3 - "$CLAUDE_MD" "$RENDERED_FILE" <<'PYEOF'
import sys
claude_md_path, rendered_path = sys.argv[1], sys.argv[2]
with open(claude_md_path) as f:
    lines = f.readlines()
with open(rendered_path) as f:
    insert = f.read()

inserted = False
out = []
state = "before_h1"
for line in lines:
    out.append(line)
    if state == "before_h1" and line.startswith("# "):
        state = "after_h1"
        continue
    if state == "after_h1" and line.strip() == "" and not inserted:
        out.append(insert + ("\n" if not insert.endswith("\n") else ""))
        inserted = True
        state = "done"

if not inserted:
    out.append("\n" + insert + ("\n" if not insert.endswith("\n") else ""))

with open(claude_md_path, "w") as f:
    f.writelines(out)
PYEOF
    rm -f "$RENDERED_FILE"
    echo "  ✓ Prepended inbox section to $CLAUDE_MD"
    CHANGED=1
  fi
fi

if [ $CHANGED -eq 0 ]; then
  echo "Nothing to do — '$SLUG' is fully wired."
else
  echo ""
  echo "Done. The agent needs to be restarted to pick up new hooks/CLAUDE.md."
fi
