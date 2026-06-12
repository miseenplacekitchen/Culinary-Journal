from pathlib import Path

base = Path(__file__).resolve().parent
files = [
    "fix-phase39-data-integrity.sql",
    "fix-phase40-meal-planner-picker.sql",
]
out = base / "RUN-IN-SUPABASE-phases-39-40-ONLY.sql"
header = """-- =============================================================================
-- PHASES 39 + 40 ONLY — use if you already ran fix-all-live and library-unified
-- Copy entire file → Supabase SQL Editor → Run
-- =============================================================================

"""
parts = [header]
for name in files:
    path = base / name
    parts.append(f"\n-- ########## BEGIN: {name} ##########\n")
    parts.append(path.read_text(encoding="utf-8"))
    if not parts[-1].endswith("\n"):
        parts.append("\n")
parts.append("\nSELECT pg_notify('pgrst', 'reload schema');\n")
parts.append("SELECT 'PHASES 39-40 COMPLETE' AS status;\n")
out.write_text("".join(parts), encoding="utf-8")
print(f"Wrote {out} ({out.stat().st_size} bytes)")
