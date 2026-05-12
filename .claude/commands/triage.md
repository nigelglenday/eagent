---
description: Run an email triage cycle across all configured inboxes
---

Read and follow the instructions in `$EA_DATA_DIR/prompts/email-triage.md` to run a full email triage cycle.

Process:
1. Read the triage prompt fully — it's the brain of this skill
2. Process unread inbound across all configured email accounts
3. Scan recently-sent for outbound notes and draft-vs-sent diffs
4. (Optional) Scan Notion for new transcripts — surface only, don't auto-extract
5. Produce the digest at `$EA_DATA_DIR/inbox-digests/YYYY-MM-DD-HHam.md`
6. Update task.md (as `[T]`-prefixed candidate tasks), kb/*, and pipeline files as warranted
7. Queue any drafts in the email client's drafts folder (never auto-send)

Default to **surface more, decide less, ask when uncertain.**

When done, give the user a 3-line summary:
- Volume (X processed, Y drafts queued, Z things needing attention)
- Top 1-2 things they should look at first
- Any uncertainty you flagged for them to resolve
