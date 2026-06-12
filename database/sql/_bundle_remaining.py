from pathlib import Path

base = Path(__file__).resolve().parent
files = [
    "fix-phase44-library-profiles.sql",
    "fix-phase45-site-fill.sql",
    "fix-phase46-library-profiles.sql",
    "fix-phase47-library-profiles.sql",
    "fix-phase48-recipe-ingredient-orphans.sql",
    "SQL-EDITOR-health-check.sql",
]
out = base / "RUN-ALL-REMAINING.sql"
header = """-- =============================================================================
-- THE CULINARY JOURNAL — RUN ALL REMAINING LIVE STEPS
-- Paste entire file in Supabase SQL Editor after site code deploy.
-- Order: library 44–47 → site fill 45 → orphan repair 48 → health verification.
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
print(f"Wrote {out} ({out.stat().st_size} bytes)")
