# Knowledge Base Schema

The persistent layer of working memory — where context accretes between conversations.

The KB has two halves:

1. **Markdown wiki here** — narrative prose, decisions, context-rich notes
2. **Optional structured graph store** — typed relationships, queryable as nodes and edges (any graph DB or knowledge graph product)

The markdown is the *story*. The graph store is the *schema*. Workers can write to both during triage cycles.

## Structure

```
kb/
├── people/          # one file per person you deal with
├── companies/       # one file per company / firm
├── themes/          # ongoing strategic narratives
└── decisions/       # one file per non-obvious decision, dated
```

## File naming

- People: `firstname-lastname.md` (lowercase, hyphenated). Use the name they go by.
- Companies: `company-name.md` (lowercase, hyphenated, no Inc/LLC).
- Themes: `topic-slug.md` (lowercase, hyphenated, descriptive).
- Decisions: `YYYY-MM-DD-short-slug.md`.

## Frontmatter schema

Every file starts with YAML frontmatter. Required fields by type:

### people/

```yaml
---
type: person
name: Jane Doe
firm: Example Corp
role: Title
relevant_for: [DomainTag1, DomainTag2]    # tag the domains this person matters to
status: active                            # active, dormant, closed, on-radar
last_touch: 2026-04-23                    # YYYY-MM-DD of most recent interaction
next_action: One-line description of what to do next.
links:
  email: jane@example.com
  linkedin:
tags: [tag1, tag2]
---
```

### companies/

```yaml
---
type: company
name: Example Corp
relevant_for: [DomainTag]
relationship: prospect                    # prospect, customer, partner, vendor, on-radar
status: active
last_touch: 2026-04-23
links:
  website:
  parent:
tags: [tag1, tag2]
---
```

### themes/

```yaml
---
type: theme
title: Strategic Theme Name
relevant_for: [DomainTag]
status: active
last_updated: 2026-05-07
related_people: [jane-doe, john-smith]
related_companies: [example-corp]
tags: [WIG, framework]
---
```

### decisions/

```yaml
---
type: decision
title: Project X / Vendor Choice
date: 2026-04-22
relevant_for: [DomainTag]
related_people: [jane-doe]
status: active                            # active, parked, reversed
---
```

## Body conventions

- **Lead with the point.** First sentence is the thing. Not setup.
- **Specifics over adjectives.** "$1M indicated demand" not "significant interest".
- **Wikilinks** to related entities: `[[jane-doe]]`, `[[example-corp]]`. Workers should write these in inline prose.
- **Append, don't overwrite.** New context goes into a dated section. Old context stays unless it's wrong.
- **Sections (loose convention):**
  - One-line summary at the top of the body
  - `## Current state` — what's true right now
  - `## History` — chronological log of touches, decisions, threads
  - `## Why this matters` — strategic relevance (only if non-obvious)
  - `## Open questions` — things to resolve

## Who writes here

- **Orchestrator** — owns all writes by default. Triggered by user brain dumps and triage handoffs.
- **Triage worker** — writes during cycles when emails or transcripts contain durable, non-obvious context.
- **Other sessions** — read-only by default. If a session has a strong KB update, append a candidate task to `task.md` (`[T]`-prefixed) and the orchestrator picks it up.

This prevents write conflicts and keeps the KB curated by a single brain.

## Optional: cross-referencing a structured graph store

If you mirror entities into a structured graph store (e.g., a knowledge graph product, a graph DB, or just a JSON file), the two should reference each other. This lets the agent navigate either direction — read narrative from markdown, query structure from the graph.

**Convention (additive frontmatter):**

```yaml
---
type: person
name: Jane Doe
firm: Example Corp
status: active
last_touch: 2026-04-23
graph_uuid: 7c4a8d4e-9f0e-4f1b-8c4e-0e9f0a1b2c3d   # ← cross-ref to graph node
---
```

The corresponding graph node gets a `kb_file` property pointing back:

```
kb_file: kb/people/jane-doe.md
```

**Bidirectional navigation:**

- Markdown narrative → graph: read `graph_uuid`, look up the node + neighborhood
- Graph structural query → narrative: read `kb_file`, open the markdown for context, history

**What lives where:**

| Graph (structural) | Markdown KB (narrative) |
|---|---|
| Typed properties (firm, role, status) | Free prose history |
| Typed relationships (reports_to, member_of) | Open questions, why this matters |
| Multi-hop queries | Voice / tone notes |
| Aggregations | Threads, conversation summaries |

The two are complementary. Don't duplicate content — graph holds the structured shape, markdown holds the running story.
