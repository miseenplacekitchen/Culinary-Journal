from pathlib import Path

base = Path(__file__).resolve().parent
files = [
    "fix-phase52-library-profiles.sql",
    "fix-phase52-lane2-recipes.sql",
    "fix-phase52-recipe-orphan-repair.sql",
    "SQL-EDITOR-health-check.sql",
]
out = base / "RUN-LIVE-PHASE52.sql"
header = """-- =============================================================================
-- THE CULINARY JOURNAL — PHASE 52 LIVE (library + Lane 2 sample recipes)
-- Paste entire file in Supabase SQL Editor after code deploy.
-- Safe to re-run.
-- =============================================================================

"""
parts = [header]
for name in files:
    path = base / name
    parts.append(f"\n-- ########## BEGIN: {name} ##########\n")
    parts.append(path.read_text(encoding="utf-8"))
    if not parts[-1].endswith("\n"):
        parts.append("\n")
    parts.append(f"-- ########## END: {name} ##########\n")
out.write_text("".join(parts), encoding="utf-8")

# Append phase 52 to RUN-ALL-REMAINING
remaining = base / "RUN-ALL-REMAINING.sql"
phase52_parts = []
for name in [
    "fix-phase52-library-profiles.sql",
    "fix-phase52-lane2-recipes.sql",
    "fix-phase52-recipe-orphan-repair.sql",
]:
    phase52_parts.append(f"\n-- ########## BEGIN: {name} ##########\n")
    phase52_parts.append((base / name).read_text(encoding="utf-8"))
    if not phase52_parts[-1].endswith("\n"):
        phase52_parts.append("\n")
    phase52_parts.append(f"-- ########## END: {name} ##########\n")

text = remaining.read_text(encoding="utf-8")
marker = "-- ########## BEGIN: SQL-EDITOR-health-check.sql"
if marker in text:
    text = text.replace(marker, "".join(phase52_parts) + marker)
else:
    text += "".join(phase52_parts)
remaining.write_text(text, encoding="utf-8")
print(f"Wrote {out} ({out.stat().st_size} bytes)")
print(f"Updated {remaining} ({remaining.stat().st_size} bytes)")
