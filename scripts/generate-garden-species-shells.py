#!/usr/bin/env python3
"""Generate draft plant shells from import-payloads for GM Apply workflow."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "brainstorm-inbox" / "import-payloads"
OUT = ROOT / "database" / "sql" / "garden-v4-13-species-shells-kitchen.sql"

# Kitchen-garden priority — species with inbox assessments + likely ingredient links
PRIORITY = [
    "bell-pepper", "basil", "cucumber", "spinach", "carrot", "potato", "pumpkin",
    "zucchini", "onion", "garlic", "coriander", "peas", "chili-pepper",
    "strawberry", "broccoli", "cabbage", "mint", "parsley",
    "thyme", "rosemary", "watermelon", "melon", "sweet-potato", "bean",
    "celery", "turnip", "radish", "beetroot",
]


def esc(s: str) -> str:
    return (s or "").replace("'", "''")


def main() -> None:
    lines = [
        "-- garden-v4-13-species-shells-kitchen.sql — draft plant rows for GM Apply pipeline",
        "-- Safe to re-run. Does not publish — set is_published in GM when ready.",
        "",
    ]
    count = 0
    for slug in PRIORITY:
        path = PAYLOADS / f"{slug}.json"
        if not path.exists():
            print(f"Skip missing payload: {slug}")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        name = data.get("species", slug.replace("-", " ").title())
        varieties = data.get("variety_count", len(data.get("varieties", [])))
        lines += [
            f"-- {name} ({varieties} cultivars in queue)",
            "INSERT INTO public.plants (slug, common_name, care_summary, is_published)",
            f"VALUES ('{esc(slug)}', '{esc(name)}',",
            f"  'Draft species shell — {varieties} cultivars in import queue. Curate in GM Interface.', false)",
            "ON CONFLICT (slug) DO NOTHING;",
            "",
        ]
        count += 1

    lines.append(f"SELECT 'garden-v4-13-species-shells ready — {count} draft species' AS status;")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {count} species shells to {OUT}")


if __name__ == "__main__":
    main()
