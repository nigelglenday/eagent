---
description: Regenerate the kb/index.md content catalog
---

Run `bash $EA_DATA_DIR/scripts/kb-index.sh` to regenerate the KB index from all kb/*/*.md files.

This produces `kb/index.md` — a catalog of every entity in the KB with one-line summaries, organized by type (people / companies / themes / decisions). Use this for quick scanning before diving into specific files.

Per Karpathy's llm-wiki pattern: this is the "what's in the wiki" entry point.

After running, briefly note the count and any new entities since last run.
