#!/bin/bash
# setup-notion-mcp.sh
# One-time setup for two Notion MCP entries (notion-A, notion-B) in
# ~/.claude.json. Tokens are NOT taken on the command line — script writes
# placeholders and opens the file in TextEdit so the user pastes them locally.
#
# Customize the slugs below if you have a different workspace topology
# (one workspace, three workspaces, etc.).

set -euo pipefail

# Edit these to match your Notion workspace names
SLUG_A="notion-A"      # e.g., "notion-personal"
SLUG_B="notion-B"      # e.g., "notion-work"

CLAUDE_JSON="$HOME/.claude.json"
BACKUP="$HOME/.claude.json.backup-$(date +%Y%m%d-%H%M%S)"

if [ ! -f "$CLAUDE_JSON" ]; then
  echo "❌ $CLAUDE_JSON not found" >&2
  exit 1
fi

cp "$CLAUDE_JSON" "$BACKUP"
echo "✓ Backed up to $BACKUP"

TMP=$(mktemp)
jq --arg a "$SLUG_A" --arg b "$SLUG_B" '
  .mcpServers[$a] //= {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@notionhq/notion-mcp-server"],
    "env": {
      "NOTION_TOKEN": "PLACEHOLDER_PASTE_WORKSPACE_A_TOKEN_HERE"
    }
  } |
  .mcpServers[$b] //= {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@notionhq/notion-mcp-server"],
    "env": {
      "NOTION_TOKEN": "PLACEHOLDER_PASTE_WORKSPACE_B_TOKEN_HERE"
    }
  }
' "$CLAUDE_JSON" > "$TMP"

mv "$TMP" "$CLAUDE_JSON"
echo "✓ Added $SLUG_A and $SLUG_B stubs to $CLAUDE_JSON"

cat <<INSTRUCTIONS

────────────────────────────────────────────────────────────────
NEXT STEPS — get tokens from each Notion workspace and paste them
────────────────────────────────────────────────────────────────

For EACH workspace:

1. Open Notion in that workspace
2. Go to: Settings → Connections → Develop or manage integrations
   (or directly: https://www.notion.so/profile/integrations)
3. "+ New integration" — pick the correct workspace from the dropdown
   - Name: a descriptive name (e.g., "Claude Code Agent")
   - Type: Internal
   - Permissions: Read content, Update content, Insert content
4. Copy the "Internal Integration Secret" (starts with \`ntn_...\` or \`secret_...\`)
5. Grant the integration access ONLY to the page tree(s) the agent needs:
   - Navigate to the parent page/database
   - Top-right "..." → Connections → add your integration
   (This grants access to that page tree only — narrow scope.)
6. TextEdit will open your ~/.claude.json — replace each
   PLACEHOLDER_PASTE_WORKSPACE_*_TOKEN_HERE with the integration secret.
   Save and close.
7. Restart any running Claude Code sessions to pick up the new MCPs.

Opening ~/.claude.json in TextEdit now...
INSTRUCTIONS

open -a TextEdit "$CLAUDE_JSON"

echo ""
echo "After saving the file, verify with:"
echo "  jq '.mcpServers | to_entries[] | select(.key | startswith(\"notion\")) | {key, has_placeholder: (.value.env.NOTION_TOKEN | startswith(\"PLACEHOLDER\"))}' ~/.claude.json"
