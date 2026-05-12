#!/bin/bash
# kb-lint.sh
# Audit the KB for problems Karpathy's llm-wiki pattern flags:
# - Schema violations (missing required frontmatter)
# - Stale entries (last_touch too old, status: active)
# - Orphan files (no other file references them)
# - Broken wikilinks ([[entity]] points to non-existent file)
# - Filename/slug mismatches
#
# Usage:
#   kb-lint.sh                  # report to stdout
#   kb-lint.sh --save           # also write to kb/lint-reports/YYYY-MM-DD.md
#   kb-lint.sh --strict         # exit 1 if any issues found (for CI)

set -euo pipefail

KB_DIR="$HOME/Documents/Tasks/kb"
SAVE=0
STRICT=0
STALE_DAYS=90

while [ $# -gt 0 ]; do
  case "$1" in
    --save) SAVE=1; shift ;;
    --strict) STRICT=1; shift ;;
    --stale-days) STALE_DAYS="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

REPORT=$(STALE_DAYS_ENV="$STALE_DAYS" python3 <<'PYEOF'
import os
import re
from pathlib import Path
from datetime import datetime, timedelta

KB_DIR = Path(os.path.expanduser("~/Documents/Tasks/kb"))
STALE_DAYS = int(os.environ.get("STALE_DAYS_ENV", "90"))

REQUIRED_FIELDS = {
    'person': ['type', 'name', 'status', 'last_touch'],
    'company': ['type', 'name', 'status', 'last_touch'],
    'theme': ['type', 'title', 'status', 'last_updated'],
    'decision': ['type', 'title', 'date', 'status'],
}

def parse_frontmatter(text):
    m = re.match(r'---\n(.*?)\n---\n', text, re.DOTALL)
    if not m:
        return None, text
    body = text[m.end():]
    fm_text = m.group(1)
    fm = {}
    for line in fm_text.splitlines():
        if ':' not in line:
            continue
        k, _, v = line.partition(':')
        v = v.strip()
        if v.startswith('[') and v.endswith(']'):
            v = [x.strip() for x in v[1:-1].split(',') if x.strip()]
        else:
            v = v.strip().strip('"').strip("'")
        fm[k.strip()] = v
    return fm, body

def slugify(s):
    s = s.lower()
    s = re.sub(r'[^a-z0-9]+', '-', s)
    return s.strip('-')

issues = {
    'schema': [],
    'stale': [],
    'orphan': [],
    'broken_wikilink': [],
    'slug_mismatch': [],
}

# Collect all KB files
all_files = []
for sub in ['people', 'companies', 'themes', 'decisions']:
    d = KB_DIR / sub
    if not d.is_dir():
        continue
    for f in d.glob('*.md'):
        if f.name in ('README.md', 'index.md', 'log.md'):
            continue
        all_files.append(f)

# Parse all files; build name → file index for cross-referencing
parsed = {}
slug_to_file = {}
for f in all_files:
    text = f.read_text()
    fm, body = parse_frontmatter(text)
    parsed[f] = (fm or {}, body)
    slug_to_file[f.stem] = f

# Schema check
for f, (fm, body) in parsed.items():
    if not fm:
        issues['schema'].append(f"{f.relative_to(KB_DIR.parent)}: no frontmatter at all")
        continue
    type_ = fm.get('type', '')
    required = REQUIRED_FIELDS.get(type_, [])
    if not required:
        issues['schema'].append(f"{f.relative_to(KB_DIR.parent)}: unknown or missing type '{type_}'")
        continue
    missing = [k for k in required if not fm.get(k)]
    if missing:
        issues['schema'].append(f"{f.relative_to(KB_DIR.parent)}: missing required fields: {', '.join(missing)}")

# Stale check (only for status: active)
cutoff = datetime.now() - timedelta(days=STALE_DAYS)
for f, (fm, body) in parsed.items():
    if fm.get('status') != 'active':
        continue
    lt = fm.get('last_touch') or fm.get('last_updated')
    if not lt:
        continue
    try:
        lt_date = datetime.strptime(lt[:10], '%Y-%m-%d')
    except ValueError:
        continue
    if lt_date < cutoff:
        days = (datetime.now() - lt_date).days
        issues['stale'].append(f"{f.relative_to(KB_DIR.parent)}: last touch {lt} ({days} days ago)")

# Wikilink + orphan check
WIKILINK_RE = re.compile(r'\[\[([a-z0-9-]+)\]\]', re.IGNORECASE)
referenced_by = {}  # slug -> set of files that reference it
referenced_targets = set()
broken_links = []

for f, (fm, body) in parsed.items():
    text = (body or '')
    for m in WIKILINK_RE.finditer(text):
        target = m.group(1).lower()
        referenced_targets.add(target)
        if target not in slug_to_file:
            broken_links.append((f.relative_to(KB_DIR.parent), target))
        else:
            referenced_by.setdefault(target, set()).add(f)

# Orphans: files no one references
for f in all_files:
    slug = f.stem
    if slug not in referenced_by:
        # Skip themes (often top-level, may not be referenced)
        if 'themes' in f.parts or 'decisions' in f.parts:
            continue
        issues['orphan'].append(f"{f.relative_to(KB_DIR.parent)}: no [[wikilinks]] from any other file")

# Broken wikilinks
for src, target in broken_links:
    issues['broken_wikilink'].append(f"{src}: references [[{target}]] but no such file")

# Slug mismatch (name slug != filename)
for f, (fm, body) in parsed.items():
    if fm.get('type') not in ('person', 'company'):
        continue
    name = fm.get('name', '')
    if not name:
        continue
    expected = slugify(name)
    actual = f.stem
    if expected != actual:
        issues['slug_mismatch'].append(f"{f.relative_to(KB_DIR.parent)}: name '{name}' would slug to '{expected}', but filename is '{actual}'")

# Report
out = []
out.append("# KB Lint Report")
out.append("")
out.append(f"*Generated: {datetime.now().strftime('%Y-%m-%d %H:%M UTC')}*")
out.append(f"*KB scanned: {len(all_files)} files*")
out.append(f"*Stale threshold: {STALE_DAYS} days*")
out.append("")

total = sum(len(v) for v in issues.values())
if total == 0:
    out.append("✅ No issues found.")
else:
    out.append(f"⚠️  {total} issue(s) found across {sum(1 for v in issues.values() if v)} categories.")
out.append("")

sections = [
    ('schema', 'Schema violations', 'Missing or invalid frontmatter fields. Fix by adding the required fields per `kb/README.md`.'),
    ('stale', f'Stale entries (>{STALE_DAYS} days, status: active)', 'Either update last_touch with new context, or change status to dormant/closed.'),
    ('orphan', 'Orphan files (no [[wikilinks]] from anywhere)', 'May be legitimate (top-level entities) or signal that the entity is not actually integrated. Consider adding cross-references.'),
    ('broken_wikilink', 'Broken wikilinks', 'A file references [[entity]] but no kb/*/entity.md exists. Either create the missing file or fix the reference.'),
    ('slug_mismatch', 'Slug / filename mismatch', 'The frontmatter `name` slugifies to something different than the filename. Pick one canonical form and rename.'),
]

for key, title, hint in sections:
    items = issues[key]
    out.append(f"## {title} — {len(items)}")
    out.append("")
    if items:
        out.append(f"_{hint}_")
        out.append("")
        for item in items:
            out.append(f"- {item}")
    else:
        out.append("(none)")
    out.append("")

print('\n'.join(out))
PYEOF
)

echo "$REPORT"

# Save report if asked
if [ "$SAVE" -eq 1 ]; then
  REPORTS_DIR="$KB_DIR/lint-reports"
  /bin/mkdir -p "$REPORTS_DIR"
  REPORT_FILE="$REPORTS_DIR/$(date -u +%Y-%m-%d).md"
  echo "$REPORT" > "$REPORT_FILE"
  echo ""
  echo "Saved: $REPORT_FILE"
fi

# Strict mode: exit 1 if any issues
if [ "$STRICT" -eq 1 ]; then
  if echo "$REPORT" | /usr/bin/grep -q '⚠️'; then
    exit 1
  fi
fi
