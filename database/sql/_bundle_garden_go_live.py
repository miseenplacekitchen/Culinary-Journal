"""Bundle Garden go-live SQL: visible pages + all species shells + batch cultivar apply."""
from pathlib import Path

base = Path(__file__).resolve().parent
files = [
    "fix-garden-v3-visible.sql",
    "garden-v4-14-all-species-shells.sql",
    "garden-v4-15-batch-apply-imports.sql",
]
out = base / "RUN-GARDEN-GO-LIVE.sql"
header = """-- =============================================================================
-- THE CULINARY JOURNAL — GARDEN GO-LIVE (step 2j)
-- Requires RUN-GARDEN-V3.sql, RUN-GARDEN-V3-POLISH.sql, RUN-GARDEN-V4.sql,
-- and garden-v4-10 import queue already applied on Supabase.
--
-- This bundle:
--   1. Flips garden pages hidden → registered (signed-in members)
--   2. Inserts draft species shells for all 208 import-queue species
--   3. Applies all queued cultivar payloads (species with shells only)
--
-- Paste THE ENTIRE FILE in Supabase SQL Editor. Safe to re-run.
-- Expect: garden pages visibility = registered; import queue mostly approved.
-- Public directory still shows only is_published species (Tomato until you publish more).
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
print(f"Wrote {out} ({out.stat().st_size:,} bytes)")
