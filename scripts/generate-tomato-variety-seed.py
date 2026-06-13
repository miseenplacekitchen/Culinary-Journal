#!/usr/bin/env python3
"""Generate garden-v4-07-seed-tomato-varieties.sql from Tomato Variety Assessment (docx preferred)."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "brainstorm-inbox" / "Variety Assessments" / "Variety Assessment_Tomato.docx"
TXT = ROOT / "brainstorm-inbox" / "_extracted_tomato.txt"
OUT = ROOT / "database" / "sql" / "garden-v4-07-seed-tomato-varieties.sql"

sys.path.insert(0, str(ROOT / "scripts"))
from garden_ingest_lib import (  # noqa: E402
    dedupe_varieties,
    parse_assessment_text,
    read_assessment_source,
    sql_seed_footer,
    sql_seed_header,
    sql_variety_block,
)


def main() -> None:
    src = DOCX if DOCX.exists() else TXT
    text, species = read_assessment_source(src)
    payload = parse_assessment_text(text, species)
    unique = dedupe_varieties(payload["varieties"])
    rel = str(src.relative_to(ROOT)).replace("\\", "/")

    lines = [
        f"-- garden-v4-07-seed-tomato-varieties.sql — auto-generated from {rel}",
        "-- Safe to re-run. Publishes cultivars for humid-subtropical + tropical-monsoon.",
        "",
    ]
    lines += sql_seed_header("tomato")
    for v in unique:
        lines += sql_variety_block("tomato", v)
    lines += sql_seed_footer(len(unique), rel, "Tomato", "tomato")

    OUT.write_text("\n".join(lines), encoding="utf-8")
    brisbane = sum(1 for v in unique if v["climate_slug"] == "humid-subtropical")
    kerala = sum(1 for v in unique if v["climate_slug"] == "tropical-monsoon")
    print(f"Wrote {len(unique)} varieties ({brisbane} Brisbane, {kerala} Kerala) to {OUT}")


if __name__ == "__main__":
    main()
