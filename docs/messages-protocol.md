# Inter-Session Messaging Protocol

File-based message queue for Claude Code sessions to coordinate without polling.

## Layout

```
$EA_DATA_DIR/messages/
├── inbox/                    # unread messages, by session slug
│   ├── ea/
│   ├── worker-a/
│   ├── worker-b/
│   └── project-c/
├── archive/                  # processed messages (mv here after handling)
└── .seen-<slug>              # per-session "newer-than" timestamp marker
```

## How a session is named

Session names match a-team agent name slugs:

| a-team name | Slug |
|---|---|
| `EA` | `ea` |
| `Worker A` | `worker-a` |
| `Project Alpha` | `project-alpha` |
| `1-K Review` | `1-k-review` |

The `check-inbox.sh` script auto-detects the slug from `$PWD` (via the a-team registry) if not passed explicitly.

## Sending a message

```bash
bash $EA_DATA_DIR/scripts/send-message.sh worker-a "Look at PR #123 — layout regression on mobile"
```

Optional flags:

```bash
send-message.sh worker-a "..." --priority urgent --notify     # macOS notification on send
send-message.sh worker-a "..." --related "issue-123,deal-x"   # add refs to frontmatter
send-message.sh worker-a "..." --from custom-source            # override sender
```

### Or via the `/sendmsg` slash command (user-level, works in any session)

If you've installed the user-level slash commands (see `user-commands/`):

```
/sendmsg worker-a Look at PR #123 — mobile regression
/sendmsg ea Process draft ready for review --notify
/sendmsg worker-b Urgent item — see thread X --priority urgent
```

The slash command wraps `send-message.sh` with argument parsing. The first whitespace-separated word is the recipient slug; the rest is the body. Flags `--priority urgent` and `--notify` work the same way.

### Or write the file directly:

```bash
cat > "$EA_DATA_DIR/messages/inbox/worker-a/$(date +%Y-%m-%d-%H%M)-pr-123-mobile-bug.md" <<EOF
---
from: ea
to: worker-a
sent_at: 2026-05-10T10:30:00Z
priority: normal
---

# PR #123 has a mobile layout regression

User reported via email this morning. Look at the diff vs main, repro on a phone-width browser.
EOF
```

## Receiving a message

Three mechanisms pick up new messages, in order of immediacy:

1. **fswatch notifier** (optional, separate install — see [README](../README.md#optional-macos-banner-when-a-message-lands)). Fires a macOS banner the moment a file lands. Event-driven, instant. You see the banner and click into the session.

2. **SessionStart hook** — fires when the user `cd`s to a session folder and runs `claude`. Reads the inbox and surfaces unread messages as a system reminder at session start. Handles the cold-start case.

3. **PreToolUse hook** — fires before each tool call. Catches messages that arrived during an active session. Only surfaces messages newer than the `.seen-<slug>` timestamp (anti-spam).

Both hooks call `$EA_DATA_DIR/scripts/check-inbox.sh <slug>`. The fswatch notifier runs `inbox-notifier.sh` via launchd.

### Manual peek via `/checkmsg` (user-level)

If you've installed the user-level slash commands, `/checkmsg` runs a manual inbox check that **ignores the `.seen` marker**:

```
/checkmsg
```

Unlike the hooks (which use `.seen` for anti-spam), the manual peek shows everything currently sitting in the inbox. Useful when a session has been idle and you want to confirm what's there. Repeatable — doesn't update the seen-marker.

When the receiving session has handled the message, it should move it to archive:

```bash
mv "$EA_DATA_DIR/messages/inbox/<slug>/<message>.md" \
   "$EA_DATA_DIR/messages/archive/"
```

The receiving session's CLAUDE.md should include the "Inter-session inbox" section (template at `scripts/templates/inbox-claude-section.md`) so the agent knows what to do with surfaced messages.

## Message format

Each message is a markdown file with YAML frontmatter:

```yaml
---
from: ea                              # sending session slug
to: worker-a                          # receiving session slug
sent_at: 2026-05-10T10:30:00Z         # ISO 8601 UTC
priority: normal                      # urgent | normal | fyi
related: ['issue-123', 'pr-456']      # optional refs
---

# Short title

Body of the message. Be specific about what you want done.
Markdown formatting is fine — tables, lists, code blocks, links all work.
```

Filename convention: `YYYY-MM-DD-HHMM-short-slug.md` (`send-message.sh` derives the slug from the body's first words).

## What this is for

- **Soft handoffs** — "I noticed X, you should look at it next time you're in"
- **Context drops** — "FYI, here's what came up while you were closed"
- **Async coordination** — "When you next run, please do X and report back via this folder"
- **Capability hand-offs** — "Add this new scan target to your loop and update your CLAUDE.md to remember"

## What this is NOT for

- **Trackable engineering work** — for that, use issue trackers (GitHub, Linear, etc.) directly
- **Real-time chat** — no daemon polls this; messages surface only on session activity
- **Tasks for the user** — those go in `task.md`, not the messages folder

## Why files, not a daemon

- Zero infrastructure
- Survives reboots, machine moves, Claude Code updates
- Auditable via `ls`
- Cheap (no polling tokens)
- Hooks fire only on session events (free when nothing's there)

## Notification on send (optional)

`send-message.sh --notify` fires a macOS notification so the user sees that a message was queued, even if the receiving session isn't open:

```bash
bash $EA_DATA_DIR/scripts/send-message.sh worker-a "..." --notify
```

This uses `osascript` to display a notification. It's NOT pushed into the receiving session — the user still has to open it. For push to external channels (Telegram, Slack), wire your own additional handler.

## Cross-machine note

If `$EA_DATA_DIR` is on a sync service (iCloud, Dropbox, syncthing), messages naturally propagate to other machines. A receiving session on a different machine sees messages next time its hooks fire.
