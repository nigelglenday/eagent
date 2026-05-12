---
description: Audit the KB for orphans, stale entries, broken wikilinks, schema violations
---

Run `bash $EA_DATA_DIR/scripts/kb-lint.sh --save` to audit the KB and save the report to `kb/lint-reports/YYYY-MM-DD.md`.

Checks:
- **Schema violations** — files missing required frontmatter (type, name, status, last_touch)
- **Stale entries** — `status: active` but `last_touch` > 90 days ago
- **Orphan files** — KB entries no other file references via [[wikilinks]]
- **Broken wikilinks** — `[[entity]]` references with no matching kb/*/entity.md
- **Slug mismatches** — `name` field slugifies to something other than the filename

Per Karpathy's llm-wiki pattern: regular lint keeps the wiki coherent.

After running, summarize the issue counts and recommend the top 1-3 things to fix or investigate. Broken wikilinks especially usually mean a missing file should be created.
