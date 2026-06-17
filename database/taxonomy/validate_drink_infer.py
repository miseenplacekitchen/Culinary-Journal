#!/usr/bin/env python3
"""Check drink-taxonomy-infer.js sub/div names against fix-sips-drinks-taxonomy.sql."""
from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SQL = ROOT / "database" / "sql" / "fix-sips-drinks-taxonomy.sql"
INFER = ROOT / "lib" / "drink-taxonomy-infer.js"

sql = SQL.read_text(encoding="utf-8")
subs: set[str] = set()
divs: set[tuple[str, str]] = set()
for sub, div in re.findall(
    r"\('Sips & Stories', '([^']+)', '([^']+)'", sql
):
    subs.add(sub)
    divs.add((sub, div))

js = INFER.read_text(encoding="utf-8")
bad_subs: set[str] = set()
bad_divs: set[str] = set()
for sub in re.findall(r'sub: "([^"]+)"', js):
    if sub and sub not in subs:
        bad_subs.add(sub)
for sub, div in re.findall(r'sub: "([^"]+)", div: "([^"]+)"', js):
    if div and (sub, div) not in divs:
        bad_divs.add(f"{sub} → {div}")

print("=== DRINK INFER — sub names NOT in Sips SQL ===")
if not bad_subs:
    print("  All rule sub names match.")
else:
    for sub in sorted(bad_subs):
        print(f"    - {sub}")

print("\n=== DRINK INFER — division names NOT in Sips SQL ===")
if not bad_divs:
    print("  All rule division names match.")
else:
    for pair in sorted(bad_divs):
        print(f"    - {pair}")

rule_count = len(re.findall(r"\{ re:", js))
print(f"\n  Rules: {rule_count} | Official subs: {len(subs)} | Official divisions: {len(divs)}")
if bad_subs or bad_divs:
    raise SystemExit(1)
