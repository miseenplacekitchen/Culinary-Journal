from pathlib import Path

base = Path(__file__).resolve().parent
parts = [
    "-- =============================================================================\n",
    "-- GARDEN v3 POLISH — run on live after RUN-GARDEN-V3.sql\n",
    "-- RPC fixes + tomato hinge repair. Safe to re-run.\n",
    "-- =============================================================================\n\n",
    (base / "garden-v3-06-rpcs.sql").read_text(encoding="utf-8"),
    "\n\n-- ########## hinge repair ##########\n\n",
    (base / "fix-garden-v3-polish.sql").read_text(encoding="utf-8"),
]
out = base / "RUN-GARDEN-V3-POLISH.sql"
out.write_text("".join(parts), encoding="utf-8")
print(f"Wrote {out} ({out.stat().st_size} bytes)")
