# Extending the Pattern

How to add new sessions, skills, hooks, MCPs, and KB entities.

---

## Add a new session

You want to spin up a new Claude Code session for a workstream — could be permanent (always part of your team) or ephemeral (one-off).

### Permanent (will recur)

```bash
# 1. Create the folder
mkdir -p $HOME/Documents/project-x

# 2. Spawn via spawn-session.sh — registers in a-team, wires inbox infra, AND launches
bash $EA_DATA_DIR/scripts/spawn-session.sh new project-x \
  $HOME/Documents/project-x \
  --category Personal \
  "Initial context: this is for [purpose]. Read /path/to/brief.md first."
```

`spawn-session.sh new` does three things in sequence:
1. Registers with the agent registry (`a-team new`)
2. Wires inbox infrastructure (`wire-inbox.sh`) — creates `.claude/settings.json` with hooks, the inbox folder under `messages/inbox/<slug>/`, and the inbox boilerplate in `.claude/CLAUDE.md`
3. Queues the initial prompt as an inbox message and launches the session

### Ephemeral (one-off, won't restore on reboot)

```bash
bash $EA_DATA_DIR/scripts/spawn-session.sh new short-task \
  /path/to/folder \
  --ephemeral \
  "[initial prompt]"
```

The `--ephemeral` flag means `a-team all` won't restore it after a reboot.

---

## Audit and heal inbox wiring for all sessions

If sessions get registered outside `spawn-session.sh` (e.g., directly via `a-team new`), they won't have inbox infrastructure wired. Run the audit:

```bash
bash $EA_DATA_DIR/scripts/audit-inboxes.sh           # report only
bash $EA_DATA_DIR/scripts/audit-inboxes.sh --fix     # auto-wire any missing
bash $EA_DATA_DIR/scripts/audit-inboxes.sh --fix --skip ephemeral
```

The audit reports settings, inbox folder, and CLAUDE.md inbox-section status for each agent in the registry.

---

## Wire SessionStart + PreToolUse hooks for an existing session

If a session was registered without inbox infrastructure, run:

```bash
bash $EA_DATA_DIR/scripts/wire-inbox.sh <slug>
```

This idempotently:
1. Creates `.claude/settings.json` with the SessionStart + PreToolUse hooks
2. Creates the inbox folder at `messages/inbox/<slug>/`
3. Injects the inbox-protocol boilerplate into the session's `.claude/CLAUDE.md` (only if not already present)

Safe to re-run.

---

## Add a new skill

Skills are markdown SOPs the orchestrator invokes for specific tasks.

### Option A — slash command (simplest)

```bash
cat > $EA_DATA_DIR/.claude/commands/my-skill.md <<EOF
---
description: Short description of what this skill does
---

[the actual prompt that the agent follows when /my-skill is invoked]
EOF

# Use it: /my-skill
```

### Option B — long-form prompt + slash command wrapper

For complex skills (like `/triage`), the prompt is too long for a slash command file. Pattern:

```bash
# 1. Write the long prompt
vim $EA_DATA_DIR/prompts/my-complex-skill.md

# 2. Wrap with a slash command
cat > $EA_DATA_DIR/.claude/commands/my-skill.md <<EOF
---
description: Short description
---

Read and follow the instructions in $EA_DATA_DIR/prompts/my-complex-skill.md.

[Brief summary of what to do, output format, etc.]
EOF
```

The `email-triage.md` prompt + `triage.md` command in this repo follow this pattern.

### Option C — user-level slash command (available in every session)

For commands you want to invoke from any Claude Code session — not just the orchestrator — put them in `~/.claude/commands/` instead of a per-session `.claude/commands/`:

```bash
cat > ~/.claude/commands/my-skill.md <<EOF
---
description: Short description
---

[the prompt]
EOF
```

This repo ships three user-level commands in `user-commands/` (install with `cp user-commands/*.md ~/.claude/commands/`):

| Command | Purpose |
|---|---|
| `/checkmsg` | Manual peek of the current session's inbox (uses `--all` to bypass anti-spam) |
| `/sendmsg <slug> <body>` | Drop a message into another session's inbox (supports `--priority urgent`, `--notify`) |
| `/start-triage-loops` | Arms three `/loop` cron jobs for scheduled triage. Run once in a triage worker session. |

---

## Add a new MCP

Edit `~/.claude.json` (user-level config) and add to `mcpServers`:

```json
{
  "mcpServers": {
    "my-mcp": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@vendor/mcp-server"],
      "env": {
        "API_KEY": "..."
      }
    }
  }
}
```

For HTTP MCPs, use `"type": "http"` and `"url": "..."` instead of command/args.

After saving, restart any Claude Code session — the MCP will be available as `mcp__my-mcp__*`.

For per-session MCPs (e.g., a project-specific connector), use `.mcp.json` in that session's folder instead.

---

## Add a new KB entity

When the orchestrator (or a worker) encounters a new person/company/theme/decision worth remembering:

```bash
cat > $EA_DATA_DIR/kb/people/firstname-lastname.md <<EOF
---
type: person
name: First Last
firm: Their Company
role: Their Role
relevant_for: [DomainTag]
status: active
last_touch: 2026-05-10
next_action: One-line description of what to do next
links:
  email: them@company.com
tags: [tag1, tag2]
---

# First Last

One-line summary.

## Current state

What's true now.

## History

- YYYY-MM-DD — what happened

## Why this matters

Strategic relevance (only if non-obvious).

## Open questions

What we still don't know.
EOF

bash $EA_DATA_DIR/scripts/kb-log.sh "Added First Last (firm)" \
  --files "kb/people/firstname-lastname.md" \
  --reason "[why]" \
  --actor "ea-triage"
```

Same pattern for companies (in `kb/companies/`), themes (in `kb/themes/`), decisions (in `kb/decisions/YYYY-MM-DD-slug.md`).

After adding, regenerate the index: `bash scripts/kb-index.sh`.

---

## Add a new project to projects.md

When a new workstream becomes worth tracking:

1. Open `projects.md` (in `$EA_DATA_DIR`)
2. Add a row to the appropriate category section
3. Set the role tag (e.g., D / O / E / S per the DOES framework, or whatever rubric you've chosen)
4. Note the doer(s), status, and a link to relevant KB if any

Example:

```markdown
| Project name | **D** | Person doing it | Active, in progress | [[related-kb-entity]] |
```

---

## Add a Routine (scheduled task)

Use [Claude Code Routines](https://code.claude.com/docs/en/web-scheduled-tasks) for scheduled / event-triggered work. Routines are configured in Claude Code Web.

Pattern:

1. In Claude Code Web, create a new Routine
2. Point it at this repo
3. Provide the prompt (e.g., `Run /triage`)
4. Set the trigger (cron, GitHub event, webhook)
5. Subscription limits apply

Use Routines when the work needs to happen on a clock or in response to an event — daily summaries, GitHub PR reviews, weekly digests.

Alternative for in-session scheduling: use the `/loop` skill in a dedicated session. See [README.md](../README.md#quick-start) for the pattern.

---

## Add a new GitHub Action

`.github/workflows/` — standard GitHub Actions.

The starter action is `validate-kb.yml` (runs lint on push). Other useful additions:

- `regenerate-index.yml` — regenerate `kb/index.md` after KB changes, commit if changed
- `weekly-summary.yml` — generate a weekly digest from `kb/log.md`
- `validate-scripts.yml` — shellcheck on bash scripts

Standard pattern:

```yaml
name: Workflow name

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  job-name:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run something
        run: bash scripts/something.sh
```

---

## Promote an ephemeral session to permanent

If a workstream becomes recurring:

1. Edit `~/.config/a-team/agents.toml`, find the `[[agent]]` block for your slug
2. Change `kind = "ephemeral"` to `kind = "persistent"`
3. Add a `category = "..."` if applicable

---

## Common patterns by goal

| I want to... | Do this |
|---|---|
| Trigger triage manually | `/triage` in an orchestrator session |
| Hand work to another session | `/sendmsg <slug> "..."` (or `bash scripts/send-message.sh`) |
| Peek my inbox manually | `/checkmsg` (uses `--all`, bypasses anti-spam) |
| Spawn a new project session | `bash scripts/spawn-session.sh new <slug> /path --ephemeral "[brief]"` |
| See what sessions exist | `bash scripts/list-agents.sh` |
| Audit / fix inbox wiring | `bash scripts/audit-inboxes.sh [--fix]` |
| Start triage on a cron | `/start-triage-loops` in the triage worker session |
| Get a banner when a message lands | Install the fswatch notifier — see [README](../README.md#optional-macos-banner-when-a-message-lands) |
| Check KB health | `/kb-lint` |
| Refresh KB catalog | `/kb-index` |
| Remember a new person | Create `kb/people/<slug>.md`, then `bash scripts/kb-log.sh ...` |
| Add a new MCP | Edit `~/.claude.json` mcpServers section, restart sessions |
