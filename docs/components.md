# Components — File-by-File Reference

What lives where. Skim this when you need to find something.

---

## Data folder contents (user-created, not in this repo)

The user's data folder (`$EA_DATA_DIR`, e.g., `$HOME/Documents/ea-data/`) is owned by the user, not this repo. Common files the orchestrator might maintain there:

| File | Role | Update cadence |
|---|---|---|
| `task.md` | Master task list (with `📨 Replies` strip per project section) | Every triage cycle + ad-hoc |
| `triage-log.md` | Rolling log of triage cycles (newest at top), linked from `task.md` | Every triage cycle |
| `inbox-digests/` | Full per-cycle triage digests, one file per cycle | Every triage cycle |
| `.ea-task-snapshot.md` | Worker's last write to `task.md` (used to diff against current for the learning loop) | Every triage cycle |
| `.ea-task-state.json` | Worker state metadata (last write timestamp, schema version) | Every triage cycle |
| `kb/themes/task-learnings.md` | Diff log: what the user deleted / edited / completed / annotated in `task.md` | Every triage cycle |
| `wafm.md` | Weekly "what actually matters" / WIGs | Weekly |
| `<role>-sync.md` | 1:1 agenda for a particular stakeholder | Per 1:1 |
| `projects.md` | Project register with DOES tags | When projects start/finish/change role |
| `sessions.md` | Notes layer over agent registry | When a session's purpose/focus changes |
| `contacts.csv` | Lightweight CRM | When contacts are added/touched |
| `PENDING.md` | External-action blockers | When something gets blocked or unblocked |

These are conventions, not requirements. Build the set that matches how you work.

---

## `kb/` — knowledge base

| Path | Contents |
|---|---|
| `kb/README.md` | Frontmatter schema, file-naming conventions |
| `kb/index.md` | Auto-generated catalog (run `scripts/kb-index.sh`) |
| `kb/log.md` | Append-only change feed, newest at top |
| `kb/lint-reports/` | Output of `scripts/kb-lint.sh --save` |
| `kb/people/<slug>.md` | One file per person |
| `kb/companies/<slug>.md` | One file per firm |
| `kb/themes/<slug>.md` | Ongoing strategic narratives, framework specs |
| `kb/decisions/YYYY-MM-DD-<slug>.md` | Non-obvious decisions, dated |

KB files use YAML frontmatter (`type`, `name`, `status`, `last_touch`, `tags`, plus type-specific fields). Body uses sections (Current state, History, Why this matters, Open questions). Wikilinks (`[[entity-slug]]`) cross-reference.

## `messages/` — inter-session messaging

| Path | Contents |
|---|---|
| `messages/inbox/<slug>/` | Unread messages per session (slug = a-team agent name slugified) |
| `messages/archive/` | Processed messages — keep for audit |
| `messages/.seen-<slug>` | Per-session timestamp file (PreToolUse anti-spam) |

Filename convention: `YYYY-MM-DD-HHMM-short-slug.md`. Frontmatter: from / to / sent_at / priority / related.

## `scripts/` — operational tools

### Session orchestration

| Script | Purpose |
|---|---|
| `lib-slugify.sh` | Sourced helpers — `slugify`, `slug_from_pwd`, `ateam_agents`, `path_from_slug` |
| `list-agents.sh [persistent\|ephemeral]` | Print the agent registry as a readable table |
| `spawn-session.sh <slug-or-name> [prompt]` | Launch an existing registered session |
| `spawn-session.sh new <slug> <path> [--ephemeral] [--category <cat>]` | Register a new agent and launch |
| `send-message.sh <to> "msg" [--from] [--priority] [--notify]` | Drop markdown into another session's inbox |
| `check-inbox.sh [slug] [--all]` | Hook callback — surfaces unread messages, seen-file anti-spam. `--all` bypasses anti-spam for manual peeks. |
| `wire-inbox.sh <slug>` | Idempotent inbox infra wiring (settings.json + folder + CLAUDE.md boilerplate) |
| `audit-inboxes.sh [--fix] [--skip ephemeral]` | Walk the agent registry, report (and optionally fix) gaps |
| `inbox-notifier.sh` | fswatch daemon — fires macOS banner the moment a message lands. Install via `install-inbox-notifier.sh`. |
| `install-inbox-notifier.sh` | One-shot installer for the fswatch + terminal-notifier daemon (handles macOS TCC). |

### Email triage

| Script | Purpose |
|---|---|
| `email-triage.sh` | Optional helper. Triage logic lives in `prompts/email-triage.md`. |

### KB management (Karpathy pattern)

| Script | Purpose |
|---|---|
| `kb-index.sh` | Generate `kb/index.md` from all KB files |
| `kb-log.sh "desc" [--files] [--reason] [--actor]` | Append entry to `kb/log.md` |
| `kb-lint.sh [--save] [--strict] [--stale-days N]` | Audit KB for problems |

### Optional integrations

| Script | Purpose |
|---|---|
| `setup-notion-mcp.sh` | One-time setup for Notion MCP server entries in `~/.claude.json` |

### Background

| Script | Purpose |
|---|---|
| `snapshot.sh` | Daily auto-commit of the data folder (run by launchd, safety net) |
| `commit-task.sh` | Commit `task.md` + worker state (`.ea-task-snapshot.md`, `.ea-task-state.json`) after every worker write. Intra-day audit trail; complements `snapshot.sh`. |

## `prompts/` — skill prompts

| File | Purpose |
|---|---|
| `email-triage.md` | The brain of the `/triage` skill. Edit to fit your inboxes, projects, voice. |

## `user-commands/` — user-level slash commands (install separately)

These commands belong at `~/.claude/commands/` (user-level) so they work in **every** Claude Code session. Install with `cp user-commands/*.md ~/.claude/commands/`.

| Command | Purpose |
|---|---|
| `/checkmsg` | Manual peek of the current session's inbox (uses `--all`, bypasses anti-spam) |
| `/sendmsg <slug> <body>` | Drop a message into another session's inbox. Supports `--priority urgent` and `--notify`. |
| `/start-triage-loops` | Arms three `/loop` cron jobs for scheduled triage (run once in a triage worker session) |

See [`user-commands/README.md`](../user-commands/README.md) for install + customization details.

## `.claude/` — Claude Code session config (orchestrator)

| File | Purpose |
|---|---|
| `.claude/CLAUDE.md` | Orchestrator identity + role spec (TEMPLATE — edit for your use) |
| `.claude/settings.json` | SessionStart + PreToolUse hooks (calls `check-inbox.sh ea`). Committed. |
| `.claude/settings.local.json` | Per-machine permissions allowlist. Local only, gitignored. |
| `.claude/commands/triage.md` | `/triage` slash command |
| `.claude/commands/kb-index.md` | `/kb-index` slash command |
| `.claude/commands/kb-lint.md` | `/kb-lint` slash command |

## `triage/` — example worker session

| File | Purpose |
|---|---|
| `triage/.claude/CLAUDE.md` | Triage worker identity (TEMPLATE — narrow brain, runs `/triage` on a cron) |
| `triage/.claude/settings.json` | Hooks for the triage worker |

## `inbox-digests/` — triage outputs (in the data folder)

One file per triage cycle: `YYYY-MM-DD-HHam.md` or `pm`. Contents typically:

- Volume summary across email accounts
- Action queue (urgent / standard / FYI)
- Drafts queued (recipient, account, subject, skill used, why drafted)
- Updates made (task list, KB, pipeline)
- Questions for the user
- Outbound notes (commitments captured, voice diffs logged)

## `drafts/` — quick drafts (in the data folder)

Working space. Not part of the formal KB. Drafts for things that don't have a home elsewhere (LinkedIn DMs, Slack messages, ad-hoc memos).

## `docs/` — these docs

| File | Purpose |
|---|---|
| `docs/architecture.md` | The "why" — patterns, decisions, design principles |
| `docs/components.md` | This file — file-by-file reference |
| `docs/extension.md` | How to add new sessions, skills, hooks, MCPs |
| `docs/kb-schema.md` | KB conventions |
| `docs/messages-protocol.md` | Inter-session messaging spec |
| `docs/does-framework.md` | Example classification rubric |

## `.github/workflows/` — CI

| File | Purpose |
|---|---|
| `.github/workflows/validate-kb.yml` | Run `kb-lint --strict` on every push (skipped if no `kb/` in repo). |

## External dependencies (not in this repo)

| Path | Purpose |
|---|---|
| `~/.claude.json` | Claude Code user-level config (MCP server registrations) |
| `~/.claude/CLAUDE.md` | Optional global instructions for all your Claude Code sessions |
| `~/.config/a-team/agents.toml` | Agent registry — source of truth for what sessions exist |
