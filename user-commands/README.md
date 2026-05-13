# User-level slash commands

These slash commands are intended to live at **user level** (`~/.claude/commands/`) so they're available in **every** Claude Code session, regardless of which folder it runs from.

## Why user-level (not per-session)

Per-session commands at `<session>/.claude/commands/` only work in that specific session. The commands here (`/checkmsg`, `/sendmsg`, `/start-triage-loops`) are designed to work everywhere — they auto-detect the current session's slug from `$PWD` via the a-team registry.

## Install

```bash
mkdir -p ~/.claude/commands
cp user-commands/*.md ~/.claude/commands/
```

After copying, the commands appear in every Claude Code session's slash-command menu. No restart needed for new sessions; existing sessions need a relaunch to discover them.

## What's here

| Command | Purpose |
|---|---|
| `/checkmsg` | Manual peek of the current session's inbox (uses `--all` to bypass anti-spam) |
| `/sendmsg <slug> <body>` | Drop a message into another session's inbox (with `--priority urgent` and `--notify` flags) |
| `/start-triage-loops` | Arm three `/loop` cron jobs for scheduled email triage (run once per triage worker session) |

## Customize for your data folder

The commands reference `$EA_DATA_DIR` with a default of `$HOME/Documents/ea-data`. If your data folder is elsewhere, either:

- Set `EA_DATA_DIR` in your shell profile (`~/.zshrc` or `~/.bash_profile`) so it's available to Claude Code sessions
- Or search-and-replace the path in each command file
