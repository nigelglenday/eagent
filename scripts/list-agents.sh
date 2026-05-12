#!/bin/bash
# list-agents.sh
# Print the a-team registry as a readable table. EA reads this to know what
# sessions exist.
#
# Usage:
#   list-agents.sh            # all agents
#   list-agents.sh persistent # only persistent
#   list-agents.sh ephemeral  # only ephemeral

set -euo pipefail

source "$(dirname "$0")/lib-slugify.sh"

FILTER="${1:-all}"

printf "%-22s %-26s %-12s %-15s %s\n" "SLUG" "NAME" "KIND" "CATEGORY" "PATH"
printf "%-22s %-26s %-12s %-15s %s\n" "----" "----" "----" "--------" "----"

ateam_agents | while IFS='|' read -r slug name path kind category; do
  case "$FILTER" in
    all) ;;
    persistent) [ "$kind" = "persistent" ] || continue ;;
    ephemeral) [ "$kind" = "ephemeral" ] || continue ;;
  esac
  # Truncate path for display
  short_path="$path"
  if [ ${#path} -gt 60 ]; then
    short_path="...${path: -57}"
  fi
  printf "%-22s %-26s %-12s %-15s %s\n" "$slug" "$name" "$kind" "$category" "$short_path"
done
