from pathlib import Path

base = Path(__file__).resolve().parent
files = [
    "garden-v4-01-varieties.sql",
    "garden-v4-02-climates-regions.sql",
    "garden-v4-02b-tomato-climate-extend.sql",
    "garden-v4-02c-tomato-monsoon-extend.sql",
    "garden-v4-03-user-climate.sql",
    "garden-v4-04-import-queue.sql",
    "garden-v4-05-rpcs.sql",
    "garden-v4-06-rls.sql",
    "garden-v4-07-seed-tomato-varieties.sql",
    "garden-v4-08-lookups.sql",
    "garden-v4-09-import-rpcs.sql",
]
out = base / "RUN-GARDEN-V4.sql"
header = """-- =============================================================================
-- THE CULINARY JOURNAL — GARDEN v4 (varieties + climate-first + tomato cultivars)
-- Requires RUN-GARDEN-V3.sql (+ polish) already applied on Supabase.
-- Paste THE ENTIRE FILE in SQL Editor. Safe to re-run.
-- =============================================================================

"""
parts = [header]
for name in files:
    path = base / name
    if not path.exists():
        raise SystemExit(f"Missing {path}")
    parts.append(f"\n-- ########## BEGIN: {name} ##########\n")
    parts.append(path.read_text(encoding="utf-8"))
    if not parts[-1].endswith("\n"):
        parts.append("\n")
    parts.append(f"-- ########## END: {name} ##########\n")
out.write_text("".join(parts), encoding="utf-8")
print(f"Wrote {out} ({out.stat().st_size} bytes)")
