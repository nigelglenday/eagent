# Architecture

The "why" of this pattern. Read [README.md](../README.md) first for the "what."

---

## System / data split

Two directories, two purposes, two repositories:

| | System repo (this one) | Data folder |
|---|---|---|
| Where it lives | `$HOME/code/ea/` (or wherever you cloned) | `$EA_DATA_DIR` (default `$HOME/Documents/ea-data/`) |
| What it contains | Scripts, prompts, schema, hooks, slash commands, docs | Your personal task list, KB entries, messages, drafts, digests |
| Backed up via | Git (this repo) | Local backup of your choice (Time Machine, iCloud, private git, etc.) |
| Audience | Public — generic scaffolding | Always private — never leaves your control |

The data folder symlinks the system into itself for Claude Code's identity (`.claude/CLAUDE.md`, `.claude/settings.json`, `.claude/commands/`) and for tool paths (`scripts/`, `prompts/`). This way `cd $EA_DATA_DIR && claude` opens a session that loads its identity and scripts from the system repo while operating on the data in the data folder.

**Why this split?** Different artifacts, different audiences, different security profiles. The system is reusable scaffolding. The data is personal context. Keeping them separate means the system stays publishable; the data never accidentally leaves the user's machine.

---

## Three architectural patterns layered

### 1. Orchestrator at the desk

The orchestrator is a long-running named Claude Code session in the data folder. The folder *is* the agent — `.claude/CLAUDE.md` is its identity, `.claude/settings.json` wires its hooks, `kb/` holds its accumulated knowledge, `scripts/` are its operational tools.

It's **always-on (when the laptop is open)**. It's the coordination layer for everything the user runs. Other Claude Code sessions exist for domain-specific work (a "Sidekick" for coding, a "Wirehouse worker" for sales ops, project-specific workspaces, etc.), but the orchestrator is the synthesizer.

**Why a single orchestrator, not federated by domain?** Cross-pollination is the value. Splitting destroys that synthesis. Federation already happens at the **session level** — the orchestrator stays unified above it.

### 2. Agent registry separate from the brain

An external agent registry (e.g., `a-team`) maintains the list of agents in TOML at `~/.config/a-team/agents.toml`:

- Distinguishes persistent (always part of the team) from ephemeral (one-off) agents
- Spawns terminal windows running Claude Code in the right folder
- Restores everything after a reboot

The orchestrator **uses** the registry, but doesn't duplicate it. It reads the TOML to know what sessions exist (`scripts/list-agents.sh`); it calls registry commands to spawn (`scripts/spawn-session.sh`).

**Why this split?** Registry mechanics are generic. The orchestrator's judgment is opinionated. Separating them keeps each focused.

### 3. Karpathy llm-wiki for the knowledge base

Per Karpathy's [LLM-wiki pattern](https://karpathy.bearblog.dev/llm-wiki/), the KB follows a three-layer architecture:

| Layer | Implementation |
|---|---|
| Raw sources (immutable) | Emails, drafts, transcripts, meeting notes |
| The wiki (LLM-curated) | `kb/people/`, `kb/companies/`, `kb/themes/`, `kb/decisions/` |
| The schema (CLAUDE.md spec) | `kb/README.md` (frontmatter conventions) + `.claude/CLAUDE.md` (orchestrator behavior) |

Plus three operations:

- **Ingest** — email triage worker
- **Query** — the orchestrator reads KB on demand when relevant
- **Lint** — `scripts/kb-lint.sh` audits for orphans, stale entries, broken wikilinks, schema violations

Plus two organizing tools:

- `kb/index.md` — auto-generated catalog (run `scripts/kb-index.sh`)
- `kb/log.md` — append-only change feed (call `scripts/kb-log.sh` from any KB write)

This is Karpathy's pattern at file-per-entity granularity. He uses one big wiki file; this version uses many small ones. Same principle, different fragmentation. The multi-file version scales beyond a single context window.

---

## Memory architecture (three layers)

| Layer | What it stores | Retrieval | Best for |
|---|---|---|---|
| **Optional structured graph store** | Structural facts (who/what/how) | Typed queries (deterministic) | "Who approves wires over $100K?" |
| **Markdown KB** | Per-entity narrative (history, voice, threads) | grep + wikilinks (full-text) | "What do we know about X?" |
| **LLM auto-memory** | Stable facts about the user + feedback | Loaded automatically at session start | "How does the user like to work?" |

Each layer for its job. Don't conflate them.

**Where a graph store earns its place:** typed multi-hop queries that grep can't express. "Find all Persons two hops from X who work at Y." "If we change System Z, what Processes are affected?" These need typed edges.

**Where markdown KB earns its place:** the long tail of "what do we know about X." Most practical queries grep handles fine.

**Where LLM auto-memory earns its place:** stable facts about the user that should never need to be re-discovered. Their role, priorities, working preferences. Not entity data — meta-data about the user.

---

## Inter-session communication

File-based, no daemon, hook-driven.

```
$EA_DATA_DIR/messages/
├── inbox/<slug>/                # unread, per session
└── archive/                     # processed
```

When the orchestrator wants to hand work to another session:

1. Call `bash scripts/send-message.sh <slug> "..."` — writes a markdown file to `inbox/<slug>/`
2. Next time the receiving session opens or makes a tool call, its SessionStart or PreToolUse hook fires
3. The hook calls `scripts/check-inbox.sh <slug>`, which surfaces unread messages as a system reminder
4. The receiving session reads the message, takes action, moves the file to `archive/`

Slug = a-team agent name slugified (lowercase, hyphenated). "Worker A" → `worker-a`. "Project Alpha" → `project-alpha`. `lib-slugify.sh` provides the function.

**Why files instead of a daemon or webhook?**

- Zero infrastructure
- Auditable via `ls`
- Survives reboots, machine moves, Claude Code updates
- Cheap (no polling tokens — hooks fire only on session events)
- Free when nothing's there (`check-inbox.sh` exits silently if inbox is empty)

**What it can't do:**

- Wake an idle session in real time (would need a watcher + injection — deferred)
- Push notifications to off-machine receivers (optional `--notify` flag uses osascript for local pop-ups)

---

## Email triage

Runs via `/loop /triage` in a dedicated session OR via the `/triage` slash command on demand.

The skill is a long markdown prompt at `prompts/email-triage.md`. Conservative defaults: surface more, decide less, ask when uncertain. Per-project role determines handling (see the DOES framework). Writing-skill router (different voices for different contexts). Outbound scanning + draft-vs-sent diff capture for voice modeling over time.

**Why `/loop` and not launchd?**

- Cache stays warm across cycles (much cheaper, much faster)
- Conversational — you can interrupt and steer mid-flight
- Visible — you see what's happening
- No headless-Claude-from-launchd auth fragility

Launchd is right for mechanical scripts (daily snapshots, time logging). It's wrong for judgment work like triage.

---

## DOES framework (project-role tagging)

Every project gets a tag: **D**o, **O**wn, **E**scalate, **S**upport. Drives how the triage worker handles inbound related to that project.

| Letter | Role | Triage handling |
|---|---|---|
| **D** | The user is doing the work | Surface fully, draft replies, push for action |
| **O** | The user owns outcome (someone else doing) | Surface; check whether the doer needs to be looped in instead |
| **E** | The user is the escalation path | Surface only if going sideways; otherwise KB-only |
| **S** | The user is informed-only | KB-only update; no task, no draft |

DOES tags live in `projects.md` (one entry per active project) and on individual KB files via the `does:` frontmatter field. The worker reads `projects.md` during triage to know which role applies.

See [`docs/does-framework.md`](does-framework.md) for the spec and examples.

---

## Why these decisions

A list of architectural choices and their reasoning.

| Decision | Why |
|---|---|
| Single Claude Code session per folder, identity in CLAUDE.md | Matches Claude Code's native model. Folder = agent. Easy to clone, share, version. |
| `/loop` not launchd for triage | Cache, conversational, debuggable, no auth headaches |
| File-based messaging, no daemon | Zero infra, auditable, cheap, survives everything |
| External agent registry | Don't duplicate. Generic infra (e.g., a-team) already does spawn/restore. Orchestrator owns judgment. |
| Markdown KB + Karpathy pattern | Simple, version-controllable, scales beyond context |
| Structured graph store (optional) for structural queries only | Don't make it a memory dump. Markdown handles the long tail. |
| Conservative triage defaults | Better to ask than to make a wrong call. The system learns by doing. |
| Drafts only, never auto-send | Email is high-stakes. Always queue, never send. |
| Sensitive contexts surface, never auto-handle | Some contexts (1:1s with leadership, comp, legal) are too important to risk |
