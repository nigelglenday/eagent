---
description: Manually check this session's inbox for unread messages (works in every Claude Code session)
---

Run a **manual peek** of the current session's inbox (uses `--all` to ignore the `.seen` anti-spam marker — manual checks should always show everything sitting in the inbox, regardless of whether hooks already "saw" it).

```bash
bash "${EA_DATA_DIR:-$HOME/Documents/ea-data}/scripts/check-inbox.sh" --all
```

The script auto-detects the session's slug from `$PWD` (via the a-team registry). If the session isn't in the registry, pass an explicit slug:

```bash
bash "${EA_DATA_DIR:-$HOME/Documents/ea-data}/scripts/check-inbox.sh" <slug> --all
```

Any unread messages will surface as a `<system-reminder>` listing the file paths. For each one:

1. Read the file with the Read tool
2. Take the requested action
3. Move to archive: `mv <message-path> "${EA_DATA_DIR:-$HOME/Documents/ea-data}/messages/archive/"`
4. Acknowledge briefly in chat what you did

If the inbox is empty, the script exits silently — confirm in chat: "Inbox clear."
