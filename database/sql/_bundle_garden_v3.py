from pathlib import Path

base = Path(__file__).resolve().parent
files = [
    "garden-v3-01-foundation.sql",
    "garden-v3-02-plants-ecosystem.sql",
    "garden-v3-03-kitchen-learning.sql",
    "garden-v3-04-personal-trust.sql",
    "garden-v3-05-rls-grants.sql",
    "garden-v3-06-rpcs.sql",
    "garden-v3-07-seed-slice1.sql",
    "garden-v3-08-site-pages.sql",
]
out = base / "RUN-GARDEN-V3.sql"
header = """-- =============================================================================
-- THE CULINARY JOURNAL — GARDEN v3 (Platform Data Model v3)
-- Paste entire file in Supabase SQL Editor after code deploy.
-- Additive only. Safe to re-run.
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
