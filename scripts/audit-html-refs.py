"""Scan root HTML files for missing local script/css references."""
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")
pat = re.compile(r"""(?:src|href)=["']([^"'?#]+)""")
missing = {}
for hf in sorted(f for f in os.listdir(ROOT) if f.endswith(".html")):
    path = os.path.join(ROOT, hf)
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    for m in pat.finditer(text):
        ref = m.group(1)
        if ref.startswith(("http://", "https://", "//", "mailto:", "#", "data:")):
            continue
        full = os.path.normpath(os.path.join(ROOT, ref.replace("/", os.sep)))
        if not os.path.exists(full):
            missing.setdefault(hf, set()).add(ref)
for hf, refs in sorted(missing.items()):
    print(hf)
    for r in sorted(refs):
        print("  MISSING:", r)
print("--- total pages with missing refs:", len(missing))
