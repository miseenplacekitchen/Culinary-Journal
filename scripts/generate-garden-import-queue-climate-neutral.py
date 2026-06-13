#!/usr/bin/env python3
"""
Neutralize city labels in all import-payload JSON files and refresh garden_import_queue payloads.

Outputs:
  brainstorm-inbox/import-payloads/*.json (updated in place)
  database/sql/fix-phase59-garden-import-queue-payloads-NN.sql (batched for SQL Editor)

Usage:
  python scripts/generate-garden-import-queue-climate-neutral.py
  python scripts/generate-garden-import-queue-climate-neutral.py --dry-run
  python scripts/generate-garden-import-queue-climate-neutral.py --batch-size 15
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "brainstorm-inbox" / "import-payloads"
OUT_DIR = ROOT / "database" / "sql"
OUT_PREFIX = "fix-phase59-garden-import-queue-payloads"
LEGACY_MONOLITH = OUT_DIR / f"{OUT_PREFIX}.sql"
RUN_LIST = OUT_DIR / "RUN-PHASE59-IMPORT-QUEUE-PAYLOADS.txt"

sys.path.insert(0, str(ROOT / "scripts"))
from garden_climate_copy import neutralize_import_payload  # noqa: E402
from garden_ingest_lib import esc_sql  # noqa: E402


def payload_update_block(data: dict, slug: str) -> list[str]:
    source = f"brainstorm-inbox/import-payloads/{slug}.json"
    payload_json = json.dumps(data, ensure_ascii=False).replace("'", "''")
    vc = data.get("variety_count", len(data.get("varieties", [])))
    return [
        f"-- {data.get('species', slug)} ({vc} cultivars)",
        "UPDATE public.garden_import_queue SET",
        f"  payload = '{payload_json}'::jsonb,",
        f"  variety_count = {vc}",
        f"WHERE species_slug = '{esc_sql(slug)}'",
        f"   OR source_path = '{esc_sql(source)}';",
        "",
    ]


def write_batch(batch_idx: int, blocks: list[str], species_count: int) -> Path:
    name = f"{OUT_PREFIX}-{batch_idx:02d}.sql"
    path = OUT_DIR / name
    lines = [
        f"-- {name}",
        "-- Climate-neutral import queue payloads (SQL Editor batch).",
        f"-- Species in this batch: {species_count}",
        "",
    ] + blocks + [
        f"SELECT '{name} ready — {species_count} payload(s)' AS status;",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")
    return path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--batch-size", type=int, default=15, help="Species per SQL file (SQL Editor limit)")
    ap.add_argument("--sql-only", action="store_true", help="Regenerate SQL batches from existing JSON (no JSON rewrite)")
    args = ap.parse_args()

    files = sorted(PAYLOADS.glob("*.json"))
    if not files:
        print(f"No payloads in {PAYLOADS}")
        sys.exit(1)

    queue_entries: list[tuple[str, dict]] = []

    for p in files:
        raw = p.read_text(encoding="utf-8")
        data = json.loads(raw)
        neutral = neutralize_import_payload(data)
        changed = json.dumps(neutral, sort_keys=True) != json.dumps(data, sort_keys=True)
        if changed and not args.dry_run and not args.sql_only:
            p.write_text(json.dumps(neutral, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if args.sql_only or changed:
            queue_entries.append((p.stem, neutral if changed else data))

    if args.dry_run:
        if args.sql_only:
            print(f"Would write SQL batches for {len(files)} payload files")
        else:
            would_change = sum(
                1 for p in files
                if json.dumps(neutralize_import_payload(json.loads(p.read_text(encoding='utf-8'))), sort_keys=True)
                != json.dumps(json.loads(p.read_text(encoding='utf-8')), sort_keys=True)
            )
            batches = (would_change + args.batch_size - 1) // args.batch_size or 0
            print(f"Would neutralize {would_change} of {len(files)} payload files")
            print(f"Would write {batches} SQL batch file(s) (~{args.batch_size} species each)")
        return

    if args.sql_only:
        queue_entries = [(p.stem, json.loads(p.read_text(encoding="utf-8"))) for p in files]

    if not queue_entries:
        print("No payloads to write.")
        sys.exit(0)

    # Remove legacy monolith if present
    if LEGACY_MONOLITH.exists():
        LEGACY_MONOLITH.unlink()

    # Remove old batch files
    for old in OUT_DIR.glob(f"{OUT_PREFIX}-*.sql"):
        old.unlink()

    batch_paths: list[Path] = []
    batch_idx = 0
    for i in range(0, len(queue_entries), args.batch_size):
        batch_idx += 1
        chunk = queue_entries[i : i + args.batch_size]
        blocks: list[str] = []
        for slug, data in chunk:
            blocks.extend(payload_update_block(data, slug))
        batch_paths.append(write_batch(batch_idx, blocks, len(chunk)))

    run_lines = [
        "Garden Phase 59 — import queue payload batches (paste each in Supabase SQL Editor)",
        "Run fix-phase59-garden-cultivar-climate-copy.sql first (already done if cultivars neutralized).",
        "Paste ONE file at a time in order:",
        "",
    ]
    for path in batch_paths:
        run_lines.append(path.name)
    run_lines += [
        "",
        f"Total: {len(queue_entries)} species across {len(batch_paths)} batch file(s).",
        "Do NOT use Apply all pending imports after step 1 unless all batches are applied.",
    ]
    RUN_LIST.write_text("\n".join(run_lines) + "\n", encoding="utf-8")

    print(f"Wrote SQL for {len(queue_entries)} payload(s) in {len(batch_paths)} batch file(s) + {RUN_LIST.name}")


if __name__ == "__main__":
    main()
