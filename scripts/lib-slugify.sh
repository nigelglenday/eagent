#!/bin/bash
# lib-slugify.sh
# Shared helper functions for converting a-team agent names to inbox slugs
# and looking up a-team registry data.
#
# Source this file from other scripts:
#   source "$(dirname "$0")/lib-slugify.sh"

# Path to a-team registry
ATEAM_TOML="$HOME/.config/a-team/agents.toml"

# slugify <string>
# Lowercase, replace non-alphanumeric with hyphen, collapse hyphens.
# Examples:
#   slugify "Worker A"        → worker-a
#   slugify "Project Alpha"   → project-alpha
#   slugify "1-K Review"      → 1-k-review
#   slugify "FOO BAR"         → foo-bar
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9\n' '-' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# ateam_agent_for_path <path>
# Returns the a-team agent NAME (display name) whose path matches the given path.
# Empty if no match.
ateam_agent_for_path() {
  local target="$1"
  if [ ! -f "$ATEAM_TOML" ]; then
    return
  fi
  # Parse TOML loosely — match path = "..." then look back for name
  python3 <<EOF
import re, sys
target = "$target"
try:
    with open("$ATEAM_TOML") as f:
        text = f.read()
except FileNotFoundError:
    sys.exit(0)

# Split into agent blocks
blocks = re.split(r'\n(?=\[\[agent\]\])', text)
for block in blocks:
    name_m = re.search(r'^name\s*=\s*"([^"]+)"', block, re.MULTILINE)
    path_m = re.search(r'^path\s*=\s*"([^"]+)"', block, re.MULTILINE)
    if name_m and path_m:
        if path_m.group(1) == target:
            print(name_m.group(1))
            break
EOF
}

# slug_from_pwd
# Returns slugified a-team agent name for current $PWD, or empty if not in registry.
slug_from_pwd() {
  local agent
  agent=$(ateam_agent_for_path "$PWD")
  if [ -n "$agent" ]; then
    slugify "$agent"
  fi
}

# slug_from_path <path>
# Returns slugified a-team agent name for an arbitrary path, or empty.
slug_from_path() {
  local agent
  agent=$(ateam_agent_for_path "$1")
  if [ -n "$agent" ]; then
    slugify "$agent"
  fi
}

# path_from_slug <slug>
# Returns the a-team agent path for the given slug, or empty.
path_from_slug() {
  local target="$1"
  ateam_agents | awk -F'|' -v s="$target" '$1 == s { print $3; exit }'
}

# ateam_agents
# Print all a-team agents as: slug|name|path|kind|category
# (one per line, pipe-separated for easy parsing)
ateam_agents() {
  if [ ! -f "$ATEAM_TOML" ]; then
    return
  fi
  python3 <<EOF
import re, sys
try:
    with open("$ATEAM_TOML") as f:
        text = f.read()
except FileNotFoundError:
    sys.exit(0)

def slugify(s):
    import re
    s = s.lower()
    s = re.sub(r'[^a-z0-9]+', '-', s)
    s = s.strip('-')
    return s

blocks = re.split(r'\n(?=\[\[agent\]\])', text)
for block in blocks:
    if '[[agent]]' not in block:
        continue
    name_m = re.search(r'^name\s*=\s*"([^"]+)"', block, re.MULTILINE)
    path_m = re.search(r'^path\s*=\s*"([^"]+)"', block, re.MULTILINE)
    kind_m = re.search(r'^kind\s*=\s*"([^"]+)"', block, re.MULTILINE)
    cat_m = re.search(r'^category\s*=\s*"([^"]+)"', block, re.MULTILINE)
    if name_m and path_m:
        name = name_m.group(1)
        path = path_m.group(1)
        kind = kind_m.group(1) if kind_m else "persistent"
        category = cat_m.group(1) if cat_m else ""
        print(f"{slugify(name)}|{name}|{path}|{kind}|{category}")
EOF
}
