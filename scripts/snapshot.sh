#!/bin/bash
# Auto-snapshot Documents/Tasks/ daily via launchd.
# Commits if there are changes, then pushes to origin if a remote is configured.
cd $HOME/Documents/ea-data || exit 1

# Only commit if there are changes
if /usr/bin/git diff --quiet HEAD 2>/dev/null && [ -z "$(/usr/bin/git ls-files --others --exclude-standard)" ]; then
    exit 0
fi

/usr/bin/git add -A
/usr/bin/git commit -m "snapshot $(/bin/date +%Y-%m-%d)"

# Push to origin if a remote is configured (silent if none)
if /usr/bin/git remote get-url origin >/dev/null 2>&1; then
    /usr/bin/git push origin main 2>&1 | /usr/bin/tail -5 || true
fi
