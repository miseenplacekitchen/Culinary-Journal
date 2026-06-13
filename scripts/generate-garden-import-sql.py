#!/usr/bin/env python3
"""
Generate SQL seed file from import JSON payload.
Usage:
  python scripts/generate-garden-import-sql.py brainstorm-inbox/import-payloads/tomato.json
  python scripts/generate-garden-import-sql.py --all
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "brainstorm-inbox" / "import-payloads"
SQL_DIR = ROOT / "database" / "sql"

sys.path.insert(0, str(ROOT / "scripts"))
from garden_ingest_lib import (  # noqa: E402
    dedupe_varieties,
    esc_sql,
    sql_seed_footer,
    sql_seed_header,
    sql_variety_block,
)


def generate_sql(payload: dict, source_path: str, out_path: Path) -> int:
    species_slug = payload.get("species_slug") or payload.get("species", "").lower()
    species_name = payload.get("species", species_slug)
    varieties = dedupe_varieties(payload.get("varieties") or [])
    if not varieties:
        raise ValueError(f"No varieties in payload for {species_slug}")

    lines = [
        f"-- Auto-generated cultivar seed for {species_name} ({species_slug})",
        f"-- Source: {source_path}",
        "-- Safe to re-run.",
        "",
    ]
    lines += sql_seed_header(species_slug)
    for v in varieties:
        lines += sql_variety_block(species_slug, v)
    lines += sql_seed_footer(len(varieties), source_path, species_name, species_slug)

    out_path.write_text("\n".join(lines), encoding="utf-8")
    return len(varieties)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("path", nargs="?", help="Path to one JSON payload")
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()

    paths: list[Path] = []
    if args.all:
        paths = sorted(PAYLOADS.glob("*.json"))
    elif args.path:
        paths = [Path(args.path)]
    else:
        ap.print_help()
        sys.exit(1)

    for p in paths:
        if not p.exists():
            print(f"Skip missing {p}")
            continue
        payload = json.loads(p.read_text(encoding="utf-8"))
        out_name = f"garden-v4-seed-{payload.get('species_slug', p.stem)}.sql"
        out_path = SQL_DIR / out_name
        try:
            n = generate_sql(payload, f"brainstorm-inbox/import-payloads/{p.name}", out_path)
            print(f"OK {p.name} -> {n} varieties -> {out_path.name}")
        except Exception as e:
            print(f"FAIL {p.name}: {e}")


if __name__ == "__main__":
    main()
