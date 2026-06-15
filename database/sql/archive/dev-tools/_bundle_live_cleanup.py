from pathlib import Path

base = Path(__file__).resolve().parent
files = [
    "fix-library-governed-links.sql",
    "fix-phase43-starter-library-health.sql",
    "SQL-EDITOR-health-check.sql",
]
out = base / "RUN-LIVE-CLEANUP.sql"
header = """-- =============================================================================
-- THE CULINARY JOURNAL — LIVE CLEANUP (run in Supabase SQL Editor)
-- Run this entire file on production AFTER deploying site code.
-- Order: library links -> health RPCs -> verification.
-- Safe to re-run. Expect final health_report.healthy = true.
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
