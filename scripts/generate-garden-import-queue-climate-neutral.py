#!/usr/bin/env python3
"""
Neutralize city labels in all import-payload JSON files and refresh garden_import_queue payloads.

Outputs:
  brainstorm-inbox/import-payloads/*.json (updated in place)
  database/sql/fix-phase59-garden-import-queue-payloads.sql

Usage:
  python scripts/generate-garden-import-queue-climate-neutral.py
  python scripts/generate-garden-import-queue-climate-neutral.py --dry-run
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "brainstorm-inbox" / "import-payloads"
OUT = ROOT / "database" / "sql" / "fix-phase59-garden-import-queue-payloads.sql"

sys.path.insert(0, str(ROOT / "scripts"))
from garden_climate_copy import neutralize_import_payload  # noqa: E402
from garden_ingest_lib import esc_sql  # noqa: E402


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    files = sorted(PAYLOADS.glob("*.json"))
    if not files:
        print(f"No payloads in {PAYLOADS}")
        sys.exit(1)

    lines = [
        "-- fix-phase59-garden-import-queue-payloads.sql",
        "-- Climate-neutral cultivar payloads for garden_import_queue (re-apply safe).",
        "-- Run after fix-phase59-garden-cultivar-climate-copy.sql if queue payloads still have city labels.",
        "",
    ]
    changed = 0

    for p in files:
        raw = p.read_text(encoding="utf-8")
        data = json.loads(raw)
        neutral = neutralize_import_payload(data)
        if json.dumps(neutral, sort_keys=True) == json.dumps(data, sort_keys=True):
            continue
        changed += 1
        if not args.dry_run:
            p.write_text(json.dumps(neutral, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        slug = p.stem
        source = f"brainstorm-inbox/import-payloads/{p.name}"
        payload_json = json.dumps(neutral, ensure_ascii=False).replace("'", "''")
        vc = neutral.get("variety_count", len(neutral.get("varieties", [])))
        lines += [
            f"-- {neutral.get('species', slug)} ({vc} cultivars)",
            "UPDATE public.garden_import_queue SET",
            f"  payload = '{payload_json}'::jsonb,",
            f"  variety_count = {vc}",
            f"WHERE species_slug = '{esc_sql(slug)}'",
            f"   OR source_path = '{esc_sql(source)}';",
            "",
        ]

    lines.append(
        f"SELECT 'fix-phase59-garden-import-queue-payloads ready — {changed} payload(s) neutralized' AS status;"
    )

    if args.dry_run:
        print(f"Would neutralize {changed} of {len(files)} payload files")
        return

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Updated {changed} JSON files; wrote {OUT}")


if __name__ == "__main__":
    main()
