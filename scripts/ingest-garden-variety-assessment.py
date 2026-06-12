#!/usr/bin/env python3
"""
Parse Variety Assessment docx → JSON payload for garden_import_queue.
Usage:
  python scripts/ingest-garden-variety-assessment.py "brainstorm-inbox/Variety Assessments/Variety Assessment_Tomato.docx"
  python scripts/ingest-garden-variety-assessment.py --all  # scan folder, write payloads/*.json
"""
import argparse
import json
import re
import sys
from pathlib import Path

try:
    import docx
except ImportError:
    docx = None

ROOT = Path(__file__).resolve().parents[1]
INBOX = ROOT / "brainstorm-inbox" / "Variety Assessments"
OUT = ROOT / "brainstorm-inbox" / "import-payloads"

EMOJI_LINEAGE = {"🏆": "heirloom", "🌱": "open_pollinated", "🧬": "hybrid", "🌏": "indigenous"}
CLIMATE_SECTIONS = {
    "BRISBANE": "humid-subtropical",
    "KERALA": "tropical-monsoon",
}


def slugify(name: str) -> str:
    return re.sub(r"-+", "-", re.sub(r"[^a-z0-9]+", "-", name.lower())).strip("-")


def lineage_from_title(title: str) -> str:
    if "🌏" in title:
        return "indigenous"
    if "🏆" in title:
        return "heirloom"
    if "🧬" in title:
        return "hybrid"
    if "🌱" in title:
        return "open_pollinated"
    return "open_pollinated"


def parse_text(text: str, species: str) -> dict:
    varieties = []
    current_climate = None
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        upper = line.upper()
        if "BRISBANE" in upper and "VARIETIES" in upper:
            current_climate = CLIMATE_SECTIONS["BRISBANE"]
            continue
        if "KERALA" in upper and "VARIETIES" in upper:
            current_climate = CLIMATE_SECTIONS["KERALA"]
            continue
        if not current_climate:
            continue
        if re.match(r"^[A-Z][^\n]{2,55}(?: 🏆| 🌱| 🧬| 🌏)", line):
            name = re.sub(r"\s*[🏆🌱🧬🌏]+\s*$", "", line).strip()
            varieties.append({
                "name": name,
                "slug": slugify(name),
                "lineage_type": lineage_from_title(line),
                "climate_slug": current_climate,
            })
    return {"species": species, "varieties": varieties, "variety_count": len(varieties)}


def read_docx(path: Path) -> str:
    if docx is None:
        raise RuntimeError("pip install python-docx")
    d = docx.Document(str(path))
    return "\n".join(p.text for p in d.paragraphs if p.text.strip())


def species_from_filename(path: Path) -> str:
    m = re.search(r"Variety Assessment_(.+)\.docx$", path.name, re.I)
    return m.group(1).strip() if m else path.stem


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path", nargs="?", help="Path to one docx")
    ap.add_argument("--all", action="store_true", help="Process all assessments")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)

    paths = []
    if args.all:
        paths = sorted(INBOX.glob("Variety Assessment_*.docx"))
    elif args.path:
        paths = [Path(args.path)]
    else:
        ap.print_help()
        sys.exit(1)

    for p in paths:
        if not p.exists():
            print(f"Skip missing {p}")
            continue
        try:
            text = read_docx(p)
        except Exception as e:
            print(f"FAIL {p.name}: {e}")
            continue
        species = species_from_filename(p)
        payload = parse_text(text, species)
        out_path = OUT / (slugify(species) + ".json")
        out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"OK {p.name} → {payload['variety_count']} varieties → {out_path.name}")

    print("\nNext: load payloads into garden_import_queue via GM Interface or SQL.")


if __name__ == "__main__":
    main()
