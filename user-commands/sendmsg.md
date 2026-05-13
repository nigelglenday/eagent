---
description: Send a message to another Claude Code session's inbox (e.g., /sendmsg sidekick "look at PR #123")
---

The user wants to drop a message in another session's inbox via the inter-session messaging system.

**Parse `$ARGUMENTS` as:**

- First whitespace-separated word = recipient slug (e.g., `ea`, `sidekick`, `atlas-masterworks`, `wirehouse-loop`)
- Remaining text = the message body (may be multi-word; preserve quoting)
- Optional flag `--priority urgent` anywhere in the args = high-priority message + macOS notification
- Optional flag `--notify` = trigger the macOS notification regardless of priority

**Run:**

```bash
bash "${EA_DATA_DIR:-$HOME/Documents/ea-data}/scripts/send-message.sh" <slug> "<body>" [--priority urgent] [--notify]
```

The script writes a markdown file to `${EA_DATA_DIR}/messages/inbox/<slug>/YYYY-MM-DD-HHMM-<auto-slug>.md` with proper YAML frontmatter (from / to / sent_at / priority). The receiving session surfaces it via its SessionStart or PreToolUse hook the next time it acts (or instantly if the fswatch notifier is installed).

**After sending, confirm to the user with one line:**

> Sent to `<slug>` → "<first 60 chars of body>..." (priority: <level>)

**If the slug doesn't appear to be a registered agent**, before sending, run:

```bash
bash "${EA_DATA_DIR:-$HOME/Documents/ea-data}/scripts/list-agents.sh"
```

and show the available slugs. Then proceed only if the user confirms or corrects.

**If `$ARGUMENTS` is empty or only contains a slug with no body**, show usage:

```
/sendmsg <slug> "<message body>" [--priority urgent] [--notify]

Examples:
  /sendmsg sidekick "Look at PR #123"
  /sendmsg ea "Process draft ready for review" --notify
  /sendmsg worker-b "Found new entity — Person X is COO not CTO" --priority urgent

Available recipients:
  bash "${EA_DATA_DIR:-$HOME/Documents/ea-data}/scripts/list-agents.sh"
```

**Don't add commentary, don't editorialize the message** — just route it cleanly.
