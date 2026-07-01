#!/usr/bin/env python3
"""Static Dish Index verification — run: python tests/verify-dish-index-bindings.py"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()

js = read("lib/dashboard-recipe-name-library.js")
dash = read("dashboard.html")
bulk = read("lib/dashboard-bulk-recipes.js")
sql = ""
for name in os.listdir(os.path.join(ROOT, "database/sql")):
    if name.endswith(".sql"):
        sql += read(os.path.join("database/sql", name))

rpcs = sorted(set(re.findall(r"""rpc\(\s*['"]([^'"]+)['"]""", js)))
fails = []
passes = []

for rpc in rpcs:
    if re.search(r"FUNCTION\s+public\." + re.escape(rpc) + r"\b", sql, re.I):
        passes.append(f"RPC {rpc}")
    else:
        fails.append(f"RPC missing in SQL: {rpc}")

vm = re.search(r"_SHELL_VERSION = '([^']+)'", js)
sm = re.search(r'dashboard-recipe-name-library\.js\?v=([^"]+)', dash)
if not vm or not sm or vm.group(1) != sm.group(1):
    fails.append(f"Version mismatch JS={vm.group(1) if vm else None} dash={sm.group(1) if sm else None}")
else:
    passes.append(f"Version {vm.group(1)}")

checks = [
    ("rnl-dup-btn", "Duplicates button", js),
    ("rnl-cov-btn", "Coverage button", js),
    ("admin_dish_index_duplicate_clusters", "Duplicate clusters RPC", js + sql),
    ("admin_dish_index_coverage_gaps", "Coverage gaps RPC", js + sql),
    ("admin_dish_index_queue_counts", "Queue counts RPC", js + sql),
    ("exportBulkPrintStudio", "Bulk PDF/PPTX export", bulk),
    ("syncDiStickyOffsets", "Sticky offset sync", js),
    ("#rnl-table thead th.di-sticky-0", "Sticky header CSS", dash),
]
for needle, label, hay in checks:
    if needle in hay:
        passes.append(label)
    else:
        fails.append(f"Missing: {label}")

print("Dish Index static verification\n")
print(f"PASS ({len(passes)}):")
for p in passes:
    print("  +", p)
if fails:
    print(f"\nFAIL ({len(fails)}):")
    for f in fails:
        print("  -", f)
    sys.exit(1)
print("\nAll static checks passed.")
sys.exit(0)
