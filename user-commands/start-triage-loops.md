---
description: Start the three triage loops (weekday hourly daytime, weekday evenings, weekends 3x). Run once per triage worker session.
---

Start the standard triage cadence by invoking three `/loop` jobs in sequence. Each fires `/triage` on its own cron schedule.

Run the following three slash commands, one after the other:

1. `/loop 7 8-18 * * 1-5 — run /triage`
   Weekday hourly, 8am through 6pm local, off-minute :07 (avoids fleet collision on :00).

2. `/loop 13 20,22 * * 1-5 — run /triage`
   Weekday evenings, 8:13pm and 10:13pm local.

3. `/loop 19 9,13,18 * * 0,6 — run /triage`
   Weekends, 9:19am / 1:19pm / 6:19pm local on Sat + Sun.

After all three are scheduled, confirm with the user by listing the active cron jobs and giving a one-line summary: total fires/week, and a reminder that the loops only live as long as this session stays open.

If a loop with the same cron expression already exists in this session, skip it — don't double-schedule.

> **Tune the schedule for your context.** The defaults above are arbitrary — every hour daytime is a lot of API spend. Most users will want fewer fires (e.g., 4–6/weekday). Edit this file to match your cadence preference.
