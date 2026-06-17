#!/usr/bin/env python3
"""Audit book + Sips taxonomy: source vs SQL vs site integration."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys_path = Path(__file__).resolve().parent
import sys
sys.path.insert(0, str(sys_path))
from generate_taxonomy_sql import parse_taxonomy, CATEGORY_MAP, SKIP_SQL_CATEGORY_NUMS, MD_PATH

ALL_CATS = list(CATEGORY_MAP.values())
SUBMIT = ROOT / "submit-recipe.html"
RECIPES = ROOT / "recipes.html"

text = MD_PATH.read_text(encoding="utf-8")
cats, warnings = parse_taxonomy(text)

print("=== 1. DATABASE SEED (fix-book-taxonomy.sql) ===")
parsed_totals = {}
for cat in cats:
    if cat.num in SKIP_SQL_CATEGORY_NUMS:
        continue
    d = sum(len(s.divisions) for s in cat.subs)
    parsed_totals[cat.db_name] = (len(cat.subs), d)

for name in sorted(parsed_totals):
    subs, divs = parsed_totals[name]
    print(f"  {name}: {subs} subs, {divs} divisions (expected after fix-book-taxonomy.sql)")

skipped = [c for c in cats if c.num in SKIP_SQL_CATEGORY_NUMS]
print("\n  NOT IN fix-book-taxonomy.sql (by design):")
for cat in skipped:
    divs = sum(len(s.divisions) for s in cat.subs)
    note = "dish browse — leave alone" if cat.num == 3 else "fix-sips-drinks-taxonomy.sql (21 subs, 92 divs)"
    print(f"    {cat.db_name}: {len(cat.subs)} subs, {divs} divisions ({note})")

print("\n=== 2. SUBMIT RECIPE — CATEGORY_TAXONOMY_HINTS ===")
submit = SUBMIT.read_text(encoding="utf-8")
hint_block = re.search(r"var CATEGORY_TAXONOMY_HINTS = \{([^}]+)\}", submit, re.S)
hint_cats = set(re.findall(r"'([^']+)':", hint_block.group(1) if hint_block else ""))
missing_hints = [c for c in ALL_CATS if c not in hint_cats]
if missing_hints:
    for c in missing_hints:
        print(f"  MISSING: {c}")
else:
    print(f"  OK — all {len(ALL_CATS)} categories have hints.")

print("\n=== 3. BROWSE — taxonomy maps ===")
js_cats = set(re.findall(r'"([^"]+)": \{', (ROOT / "lib/taxonomy-sub-codes.js").read_text(encoding="utf-8")))
for c in ALL_CATS:
    if c not in js_cats:
        print(f"  {c}: not in taxonomy-sub-codes.js (PART codes won't show)")
if all(c in js_cats or c == "Garden & Earth" for c in ALL_CATS):
    print("  OK — 13 taxonomy categories mapped (Garden uses dish browse).")

print("\n=== 4. AUTO-INFER ===")
print("  lib/food-taxonomy-infer.js — 12 book categories (+ Garden rules in JS, not seeded)")
print("  lib/drink-taxonomy-infer.js — Sips Parts A–D (mirrored in RecipeExtraction/tcj_extract.py)")
print("  Run: python database/taxonomy/validate_food_infer.py")
print("  Run: python database/taxonomy/validate_drink_infer.py")

print("\n=== 5. BROWSE UX (recipes.html) ===")
recipes = RECIPES.read_text(encoding="utf-8")
checks = [
    ("PART grouping", "getSubsGroupedByPart" in recipes),
    ("Category-scoped community filters", "activeCatFilter" in recipes and "p_category" in recipes),
    ("taxonomy-parts.js loaded", "taxonomy-parts.js" in recipes),
    ("Cache busters on taxonomy JS", "taxonomy-sub-codes.js?v=" in recipes),
]
for label, ok in checks:
    print(f"  {'OK' if ok else 'GAP'} — {label}")

print("\n=== 6. SUBMIT FALLBACKS & CACHE ===")
bad_fallbacks = []
if "Biryanis & Pilafs" in submit:
    bad_fallbacks.append("Biryanis & Pilafs (deprecated sub)")
if re.search(r"out\.div = 'Mutton Biryani'", submit):
    bad_fallbacks.append("Mutton Biryani used as division (is a sub-category)")
if bad_fallbacks:
    for b in bad_fallbacks:
        print(f"  GAP — {b}")
else:
    print("  OK — no deprecated biryani fallback names in submit-recipe.html")
if "food-taxonomy-infer.js?v=20260721" in submit:
    print("  OK — submit infer JS cache buster current")
else:
    print("  GAP — bump food/drink-taxonomy-infer.js ?v= on submit-recipe.html")

print("\n=== 7. MEAL PLANNER ===")
mp = (ROOT / "meal-planner.html").read_text(encoding="utf-8")
mp_checks = [
    ("Division chips scoped to selected sub", "subFilter || r.subcategory_name === subFilter" in mp),
    ("Clears division when sub changes", "divFilter = ''" in mp and "setSubFilter" in mp),
]
for label, ok in mp_checks:
    print(f"  {'OK' if ok else 'GAP'} — {label}")

print("\n=== 8. INFER VALIDATORS ===")
import subprocess
for script in ("validate_food_infer.py", "validate_drink_infer.py"):
    r = subprocess.run([sys.executable, str(Path(__file__).parent / script)], capture_output=True, text=True)
    ok = r.returncode == 0
    print(f"  {'OK' if ok else 'FAIL'} — {script}")
    if not ok and r.stdout:
        print(r.stdout[-400:])

print("\n=== 9. KNOWN INTENTIONAL GAPS ===")
print("  Garden & Earth: not in fix-book-taxonomy.sql or taxonomy-sub-codes.js (dish table browse).")
print("  Import/admin pipeline: category-only except Sips sub/div in tcj_extract.py.")
print("  meal-planner.html: flat sub list (no PART grouping headers).")

if warnings:
    print(f"\n=== PARSE WARNINGS ({len(warnings)}) ===")
    for w in warnings[:5]:
        print(f"  {w}")
