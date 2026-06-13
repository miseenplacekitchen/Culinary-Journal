#!/usr/bin/env python3
"""
Parse Variety Assessment docx → JSON payload for garden_import_queue.
Usage:
  python scripts/ingest-garden-variety-assessment.py "brainstorm-inbox/Variety Assessments/Variety Assessment_Tomato.docx"
  python scripts/ingest-garden-variety-assessment.py --all
  python scripts/ingest-garden-variety-assessment.py --all --sql
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INBOX = ROOT / "brainstorm-inbox" / "Variety Assessments"
OUT = ROOT / "brainstorm-inbox" / "import-payloads"

sys.path.insert(0, str(ROOT / "scripts"))
from garden_ingest_lib import (  # noqa: E402
    parse_assessment_text,
    read_assessment_source,
    species_slug_from_name,
)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("path", nargs="?", help="Path to one docx or txt")
    ap.add_argument("--all", action="store_true", help="Process all assessments in inbox")
    ap.add_argument("--sql", action="store_true", help="Also emit database/sql/garden-v4-seed-<slug>.sql per payload")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)

    paths: list[Path] = []
    if args.all:
        paths = sorted(INBOX.glob("Variety Assessment_*.docx"))
    elif args.path:
        paths = [Path(args.path)]
    else:
        ap.print_help()
        sys.exit(1)

    total_v = 0
    for p in paths:
        if not p.exists():
            print(f"Skip missing {p}")
            continue
        try:
            text, species = read_assessment_source(p)
            payload = parse_assessment_text(text, species)
            if not payload.get("species_slug"):
                payload["species_slug"] = species_slug_from_name(species)
            out_path = OUT / (payload["species_slug"] + ".json")
            out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
            total_v += payload["variety_count"]
            print(f"OK {p.name} -> {payload['variety_count']} varieties -> {out_path.name}")
        except Exception as e:
            print(f"FAIL {p.name}: {e}")

    if args.sql:
        import subprocess
        subprocess.run([sys.executable, str(ROOT / "scripts" / "generate-garden-import-sql.py"), "--all"], check=False)

    print(f"\nDone: {len(paths)} files, {total_v} variety rows. Load queue via scan-garden-inbox-queue.py or GM Interface.")


if __name__ == "__main__":
    main()
