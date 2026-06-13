#!/usr/bin/env python3
"""
Generate fix-phase56-garden-excel-profiles.sql from brainstorm-inbox/2025.11.09_Garden.xlsx.

Reads Master Sheet completed rows + (Quick) Plant Profile template data.
Maps cultivar-specific Excel rows (e.g. Black Beauty Tomato) onto species shells (tomato).

Usage:
  python scripts/generate-garden-excel-profiles.py
  python scripts/generate-garden-excel-profiles.py --dry-run
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "database" / "sql" / "fix-phase56-garden-excel-profiles.sql"

sys.path.insert(0, str(ROOT / "scripts"))
from garden_excel_profile_lib import load_excel_profiles, sql_plant_block  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="Print summary only")
    args = ap.parse_args()

    entries = load_excel_profiles()
    if not entries:
        print("No Excel profiles parsed — fill Master Sheet + Quick Plant Profile in Garden.xlsx")
        sys.exit(1)

    if args.dry_run:
        for e in entries:
            print(
                e["profile_key"],
                "->",
                e["species_slug"],
                "| plant fields:",
                len(e["plant_updates"]),
                "| care:",
                len(e["care_rows"]),
                "| calendar:",
                len(e["calendar_rows"]),
            )
        return

    lines = [
        "-- fix-phase56-garden-excel-profiles.sql",
        "-- Full profile ingest from Garden.xlsx (Master Sheet + Quick Plant Profile).",
        "-- Safe to re-run. Maps Excel cultivar profiles onto species shells (tomato, artichoke, …).",
        "-- Output keyed by climate_zone slug — inbox city labels neutralized at export.",
        "-- Source: brainstorm-inbox/2025.11.09_Garden.xlsx",
        "",
    ]
    for entry in entries:
        lines.extend(sql_plant_block(entry))

    lines.append(f"SELECT 'fix-phase56-garden-excel-profiles ready — {len(entries)} excel profile(s)' AS status;")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT} ({len(entries)} profiles)")


if __name__ == "__main__":
    main()
