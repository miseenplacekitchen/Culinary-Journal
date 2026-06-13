#!/usr/bin/env python3
"""
Scan import-payloads/*.json and emit SQL to load garden_import_queue (status=parsed).
Run after ingest-garden-variety-assessment.py --all
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "brainstorm-inbox" / "import-payloads"
OUT = ROOT / "database" / "sql" / "garden-v4-10-batch-import-queue.sql"

sys.path.insert(0, str(ROOT / "scripts"))
from garden_ingest_lib import esc_sql  # noqa: E402


def main() -> None:
    files = sorted(PAYLOADS.glob("*.json"))
    if not files:
        print("No payloads — run ingest-garden-variety-assessment.py --all first")
        sys.exit(1)

    lines = [
        "-- garden-v4-10-batch-import-queue.sql — load parsed Variety Assessment payloads",
        "-- Safe to re-run. Updates variety_count + payload for matching source_path.",
        "",
    ]

    for p in files:
        data = json.loads(p.read_text(encoding="utf-8"))
        slug = data.get("species_slug", p.stem)
        species = data.get("species", slug.title())
        count = data.get("variety_count", len(data.get("varieties", [])))
        source = f"brainstorm-inbox/import-payloads/{p.name}"
    lines += [
            f"-- {species} ({count} cultivars)",
            "INSERT INTO public.garden_import_queue (source_path, species_name, species_slug, climate_slug, status, variety_count, payload)",
            f"SELECT '{esc_sql(source)}', '{esc_sql(species)}', '{esc_sql(slug)}', 'multi', 'parsed', {count}, NULL::jsonb",
            f"WHERE NOT EXISTS (SELECT 1 FROM public.garden_import_queue WHERE source_path = '{esc_sql(source)}');",
            "",
            f"UPDATE public.garden_import_queue SET species_name = '{esc_sql(species)}', species_slug = '{esc_sql(slug)}',",
            f"  variety_count = {count}, status = 'parsed'",
            f"WHERE source_path = '{esc_sql(source)}' AND (payload IS NULL OR status IN ('pending','parsed'));",
            "",
        ]

    lines.append(f"SELECT 'garden-v4-10-batch-import-queue ready — {len(files)} species payloads' AS status;")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT} ({len(files)} payloads)")


if __name__ == "__main__":
    main()
