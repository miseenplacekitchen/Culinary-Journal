"""Report pages missing common SEO/shell elements."""
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")
for label, check in [
    ("NO META DESC", lambda t: 'name="description"' not in t),
    ("NO CANONICAL", lambda t: 'rel="canonical"' not in t),
    ("NO H1", lambda t: not re.search(r"<h1\b", t, re.I)),
    ("NO style.css", lambda t: "style.css" not in t),
    ("nav without supabase", lambda t: "nav-init.js" in t and "supabase-config.js" not in t),
]:
    hits = [f for f in sorted(os.listdir(ROOT)) if f.endswith(".html") and check(open(os.path.join(ROOT, f), encoding="utf-8", errors="replace").read())]
    print(label, len(hits))
    print(" ", ", ".join(hits) if hits else "(none)")
