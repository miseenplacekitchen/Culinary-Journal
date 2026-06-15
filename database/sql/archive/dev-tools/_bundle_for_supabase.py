from pathlib import Path

base = Path(__file__).resolve().parent
files = [
    "fix-all-live.sql",
    "fix-library-unified.sql",
    "fix-phase36-platform-batch.sql",
    "fix-phase36-festivals-hotfix.sql",
    "fix-phase37-festival-admin.sql",
    "fix-phase37-tools-profiles.sql",
    "fix-phase38-import-audit.sql",
    "fix-phase39-data-integrity.sql",
    "fix-phase39b-sql-editor-admin.sql",
    "fix-phase40-meal-planner-picker.sql",
    "fix-phase41-browse-pagination.sql",
    "fix-phase42-scale-mitigation.sql",
    "fix-library-governed-links.sql",
    "fix-phase43-starter-library-health.sql",
    "fix-phase44-library-profiles.sql",
    "fix-phase45-site-fill.sql",
    "fix-phase46-library-profiles.sql",
    "SQL-EDITOR-health-check.sql",
]
out = base / "RUN-IN-SUPABASE-copy-paste-this.sql"
header = """-- =============================================================================
-- THE CULINARY JOURNAL — COPY THIS ENTIRE FILE INTO SUPABASE SQL EDITOR
-- 1. Open this file in Cursor or Notepad
-- 2. Ctrl+A (select all) → Ctrl+C (copy)
-- 3. Supabase → SQL Editor → New query → Ctrl+V → Run
-- Safe to re-run.
-- After site deploy, also run RUN-LIVE-CLEANUP.sql for library links + health RPC refresh.
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
parts.append("\nSELECT pg_notify('pgrst', 'reload schema');\n")
parts.append("SELECT 'ALL PRODUCTION PATCHES COMPLETE' AS status;\n")
out.write_text("".join(parts), encoding="utf-8")
print(f"Wrote {out} ({out.stat().st_size} bytes)")
