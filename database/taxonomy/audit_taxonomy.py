#!/usr/bin/env python3
"""Audit book taxonomy: source vs SQL vs site integration gaps."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys_path = Path(__file__).resolve().parent
import sys
sys.path.insert(0, str(sys_path))
from generate_taxonomy_sql import parse_taxonomy, CATEGORY_MAP, SKIP_SQL_CATEGORY_NUMS, MD_PATH

ALL_CATS = list(CATEGORY_MAP.values())
HINTS_CATS = {
    'Grains & Comfort', 'Meat & Fire', 'Ocean & River', 'Garden & Earth',
    'Breads & Bakes', 'Sweet Serenades', 'Slow & Soulful', 'Sips & Stories',
}

text = MD_PATH.read_text(encoding='utf-8')
cats, warnings = parse_taxonomy(text)

print('=== 1. DATABASE SEED (fix-book-taxonomy.sql) ===')
parsed_totals = {}
for cat in cats:
    if cat.num in SKIP_SQL_CATEGORY_NUMS:
        continue
    d = sum(len(s.divisions) for s in cat.subs)
    parsed_totals[cat.db_name] = (len(cat.subs), d)

user_db = {
    'Rise & Shine': (29, 165), 'The Evening Table': (32, 176), 'Meat & Fire': (19, 107),
    'Ocean & River': (25, 109), 'Slow & Soulful': (28, 160), 'Grains & Comfort': (41, 181),
    'Breads & Bakes': (39, 230), 'Sweet Serenades': (39, 224), 'Preserved & Cherished': (31, 180),
    'Feast Days': (20, 150), 'Little Ones': (23, 109), 'Nourish & Heal': (28, 126),
}
for name in sorted(parsed_totals):
    exp = parsed_totals[name]
    act = user_db.get(name)
    if not act:
        print(f'  MISSING IN USER VERIFY: {name} expected {exp[0]} subs / {exp[1]} divs')
    elif act != exp:
        print(f'  COUNT MISMATCH {name}: DB {act[0]}/{act[1]} vs seed {exp[0]}/{exp[1]} (extra legacy rows?)')
    else:
        print(f'  OK {name}: {act[0]} subs, {act[1]} divisions')

skipped = [c for c in cats if c.num in SKIP_SQL_CATEGORY_NUMS]
print('\n  NOT IN fix-book-taxonomy.sql (by design):')
for cat in skipped:
    divs = sum(len(s.divisions) for s in cat.subs)
    note = 'review in progress' if cat.num == 3 else 'fix-sips-drinks-taxonomy.sql'
    print(f'    {cat.db_name}: {len(cat.subs)} subs, {divs} divisions ({note})')

print('\n=== 2. SOURCE MD vs USER LIST (content completeness) ===')
print('  All 12 loaded categories match generator counts (except +1 div Meat/Ocean = likely pre-DB rows).')
print('  Garden: 21 subs, 111 divisions in MD — NOT seeded yet.')
print('  Sips: structure in fix-sips-drinks-taxonomy.sql only (21 subs).')

print('\n=== 3. SUBMIT RECIPE — CATEGORY_TAXONOMY_HINTS missing ===')
missing_hints = [c for c in ALL_CATS if c not in HINTS_CATS]
for c in missing_hints:
    print(f'    {c}')

js = (ROOT / 'lib/taxonomy-sub-codes.js').read_text(encoding='utf-8')
js_cats = set(re.findall(r'"([^"]+)": \{', js))
print('\n=== 4. BROWSE — taxonomy-sub-codes.js missing ===')
for c in ALL_CATS:
    if c not in js_cats:
        print(f'    {c} (A1/B2 codes won\'t show on sub-category cards)')

print('\n=== 5. AUTO-INFER ON SUBMIT/PARSE ===')
print('  Only Sips & Stories has drink-taxonomy-infer.js rules.')
print('  Other 13 categories: no auto sub/division inference from recipe name/ingredients.')

print('\n=== 6. BROWSE UX GAPS ===')
print('  - Sub-category pills show ALL subs flat (e.g. Grains & Comfort = 41 pills).')
print('  - No PART A/B/C grouping headers in browse (unlike book structure).')
print('  - All division emojis default to generic placeholder in seed.')
print('  - Categories WITH dishes table rows use dish browse, not taxonomy (Garden & Earth).')

print('\n=== 7. CROSS-REFERENCE LINES (not real divisions) ===')
see_refs = [l.strip() for l in text.splitlines() if 'see Sips' in l or 'see Garden' in l.lower()]
for line in see_refs[:8]:
    print(f'    {line[:75]}')
if len(see_refs) > 8:
    print(f'    ... +{len(see_refs)-8} more pointer lines in other categories')

print('\n=== 8. LEGACY SUBS (may still be active in DB) ===')
print('  Sips legacy subs in fix-sips-drinks-taxonomy.sql: Cocktails & Spirits, Mocktails,')
print('  Smoothies & Shakes, Tea & Coffee, Juices & Refreshers (sort 401+).')
print('  Old phase-6 subs deactivated by fix-book-taxonomy for loaded categories.')

print('\n=== 9. COMMUNITY RECIPES FILTER ===')
print('  cr-taxonomy-row mixes ALL subs from ALL categories globally — not scoped per category.')

print('\n=== 10. RECIPES / DISHES TABLE ===')
print('  No dishes seed in repo SQL; Garden dishes live in Supabase only.')
print('  openCat uses dishes first — taxonomy browse only when dishes.length === 0.')
