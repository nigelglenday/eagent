---
type: theme
title: DOES Framework — Role-on-Project Classification
status: example
last_updated: 2026-05-12
tags: [framework, prioritization, accountability]
---

# DOES Framework

One example rubric for classifying your role on any given project. Use these tags everywhere — `task.md`, KB person/company files, project files. The triage worker reads these tags to know how aggressively to handle inbound related to that project.

> **Note:** This is one example. The pattern is "tag projects with role classifications and route inbound by tag." The specific letters and definitions are yours to choose. The triage prompt at `prompts/email-triage.md` references DOES — if you replace this, update that prompt too.

## The four roles

| Letter | Role | What it means |
|---|---|---|
| **D** | **Do** | You are actively doing the work. Hands-on. |
| **O** | **Own** | You own the outcome but aren't necessarily doing the work. May or may not have hands on it. Accountable for delivery. |
| **E** | **Escalate** | Passive role. You are the point of escalation if something goes wrong. Otherwise stay out. |
| **S** | **Support** | Informed and in a support role. Get the updates; don't drive. |

## How triage uses this

When processing email or shaping tasks, the DOES tag on the related project tells the worker how to handle it:

- **Do** → surface fully, draft replies, push for action
- **Own** → surface, but check whether the doer needs to be looped in, not you
- **Escalate** → only surface if something is going sideways. Otherwise, KB-only update.
- **Support** → KB-only update. No task. No draft. Just record the context.

## Tagging convention

In `task.md`, prefix tasks with the DOES role:

```
- [ ] **[D] Send the X process map** ⏱1hr
- [ ] **[O] Outreach campaign Y** — Alice executing, you own the outcome
- [ ] **[E] Project Z review** — outside firm running it, escalate if scope shifts
- [ ] **[S] Initiative W** — Bob doing it, you're informed
```

In KB files, set DOES in frontmatter:

```yaml
---
does: D                    # for the related project
---
```

## Why this matters

If you're running multiple workstreams, every email feels like it requires action. With explicit role tags, the triage worker can default to silence on Support items and only escalate when the role demands it.

This is the structural answer to "what counts as a task vs KB-only." Not a rule, a role. The same email can be handled four different ways depending on the project tag.

## Adapting this

If DOES doesn't fit how you think about your work, replace it with what does. Common alternatives:

- **RACI** (Responsible / Accountable / Consulted / Informed) — classic project management
- **Priority tiers** (P0 / P1 / P2 / P3) — pure urgency
- **Domain tags** (DOMAIN/CLIENT/INTERNAL/etc.) — by area instead of role

Whatever rubric you choose, encode the routing logic in `prompts/email-triage.md` so the triage worker applies it consistently.
