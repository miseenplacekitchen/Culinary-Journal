"""Fix mojibake in dashboard-recipes.js from UTF-8/cp1252 corruption."""
from pathlib import Path

PATH = Path(__file__).resolve().parent.parent / "dashboard-recipes.js"
text = PATH.read_text(encoding="utf-8")

PLATE = "\U0001f37d"

REPLACEMENTS = [
    ("// The Culinary Journal \u2014 Dashboard Module", "// The Culinary Journal — Dashboard Module"),
    ("// The Culinary Journal \u00e2\u20ac\u201d Dashboard Module", "// The Culinary Journal — Dashboard Module"),
    ("\u00e2\u20ac\u201c", "\u2014"),
    ("\u00e2\u20ac\u201d", "\u2014"),
    ("\u00e2\u20ac\u2014", "\u2014"),
    ("\u00e2\u20ac\xa6", "\u2026"),
    ("\u00e2\u2020\u2019", "\u2192"),
    ("\u00e2\u2020\u2018", "\u2191"),
    ("\u00e2\u2020\u201c", "\u2193"),
    ("\u00e2\u2013\xbc", "\u25bc"),
    ("\u00e2\u2013\xb6", "\u25b6"),
    ("\u00c2\xb7", "\u00b7"),
    ("\u00f0\u0178\u008d\u00bd", PLATE),
    ("\u00d4\u00e5\u00c6", "\u2192"),
    ("\u00d4\u00c7\u00f6", "\u2014"),
]

for old, new in REPLACEMENTS:
    text = text.replace(old, new)

bad = ["\u00e2\u20ac", "\u00e2\u2020", "\u00e2\u2013", "\u00f0\u0178", "\u00d4\u00e5", "\u00d4\u00c7"]
remaining = sum(text.count(b) for b in bad)
print("Remaining suspicious fragments:", remaining)
PATH.write_text(text, encoding="utf-8", newline="\r\n")
print("Wrote", PATH)
