# Changelog

All notable changes to `eagent` are documented here.

This file roughly follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-05-18

- **Reply-strip in `task.md`** — incoming reply context is stripped down to actionable items before landing in the task list, reducing noise.
- **Learning loop** — corrections feed back into prompts so the agent gradually adapts.
- **Per-write git commits** — every KB write commits, giving full audit history of what the agent changed and when.
- **Slash commands** at the user level: `/checkmsg`, `/sendmsg`, `/start-triage-loops`.
- **fswatch inbox notifier** — optional macOS banner when inter-session messages arrive, using terminal-notifier (with osascript fallback).
- **`--all` flag** on `check-inbox.sh` for manual peek mode.
- **Triage log convention** — `triage-log.md` for hourly inbox digest entries.
- **Documentation** — figlet 3-D banner, reply strip / triage log / learning loop docs.

## [0.1.0] - 2026-05-12

Initial release. Pattern template: `.claude/` config, `triage/` worker session, file-based `messages/` inter-session messaging, markdown KB conventions, optional Graphite Atlas mirror.
