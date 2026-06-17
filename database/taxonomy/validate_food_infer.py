#!/usr/bin/env python3
"""Check food-taxonomy-infer.js sub/div names against book taxonomy."""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_taxonomy_sql import MD_PATH, SKIP_FOOD_INFER_CATEGORY_NUMS, parse_taxonomy

ROOT = Path(__file__).resolve().parents[2]
INFER = ROOT / "lib" / "food-taxonomy-infer.js"

text = MD_PATH.read_text(encoding="utf-8")
cats, _ = parse_taxonomy(text)
subs_by_cat: dict[str, set[str]] = {}
divs_by_cat: dict[str, set[tuple[str, str]]] = {}
for cat in cats:
    if cat.num in SKIP_FOOD_INFER_CATEGORY_NUMS:
        continue
    subs_by_cat[cat.db_name] = {s.name for s in cat.subs}
    divs_by_cat[cat.db_name] = {(s.name, d.name) for s in cat.subs for d in s.divisions}

js = INFER.read_text(encoding="utf-8")
blocks = re.findall(r'"([^"]+)": \[(.*?)\]\s*,?', js, re.S)
bad_subs: dict[str, set[str]] = defaultdict(set)
bad_divs: dict[str, set[str]] = defaultdict(set)

for cat, body in blocks:
    actual_subs = subs_by_cat.get(cat, set())
    actual_divs = divs_by_cat.get(cat, set())
    for sub in re.findall(r'sub: "([^"]+)"', body):
        if sub and sub not in actual_subs:
            bad_subs[cat].add(sub)
    for sub, div in re.findall(r'sub: "([^"]+)", div: "([^"]+)"', body):
        if div and (sub, div) not in actual_divs:
            bad_divs[cat].add(f"{sub} → {div}")

print("=== FOOD INFER — sub names NOT in book taxonomy ===")
if not bad_subs:
    print("  All rule sub names match.")
else:
    for cat in sorted(bad_subs):
        print(f"  {cat}:")
        for sub in sorted(bad_subs[cat]):
            print(f"    - {sub}")

print("\n=== FOOD INFER — division names NOT in book taxonomy ===")
if not bad_divs:
    print("  All rule division names match.")
else:
    for cat in sorted(bad_divs):
        print(f"  {cat}:")
        for pair in sorted(bad_divs[cat])[:10]:
            print(f"    - {pair}")
        if len(bad_divs[cat]) > 10:
            print(f"    ... +{len(bad_divs[cat]) - 10} more")

rule_count = len(re.findall(r"new RegExp", js))
print(f"\nTotal infer rules: {rule_count}")
