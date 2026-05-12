## Inter-session inbox (messages from EA / other agents)

You have an inbox at `${EA_DATA_DIR:-$HOME/Documents/ea-data}/messages/inbox/__SLUG__/`. The EA orchestrator (and occasionally other sessions) drop markdown files there when they need to hand work to you — e.g., a new scanning capability to add, a config change, a context update.

A SessionStart + PreToolUse hook calls `check-inbox.sh __SLUG__` automatically. If there are unread messages, you'll see a `<system-reminder>` flagging them at the top of your context. The reminder lists the file paths.

**When you see that reminder:**

1. **Read every flagged message** with the Read tool (full path is in the reminder)
2. **Take the requested action** — message body will tell you what
3. **Move the file to archive** when done: `mv <message-path> ${EA_DATA_DIR:-$HOME/Documents/ea-data}/messages/archive/`
4. **Acknowledge briefly** in chat what you did (one line is enough)

If a message asks you to fundamentally change how you operate (new scanning target, new logging destination, etc.), update this CLAUDE.md with the new instruction so the change persists across restarts.

If you can't do what a message asks, reply to EA's inbox:

```bash
bash ${EA_DATA_DIR:-$HOME/Documents/ea-data}/scripts/send-message.sh ea "<your reply>" --from __SLUG__
```

**Don't skip messages.** They're intentional handoffs.

---
