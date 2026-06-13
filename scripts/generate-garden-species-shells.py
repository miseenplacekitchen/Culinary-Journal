#!/usr/bin/env python3
"""Generate draft plant shells from import-payloads for GM Apply workflow."""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "brainstorm-inbox" / "import-payloads"

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


def shell_lines(slug: str, data: dict) -> list[str]:
    name = data.get("species", slug.replace("-", " ").title())
    varieties = data.get("variety_count", len(data.get("varieties", [])))
    return [
        f"-- {name} ({varieties} cultivars in queue)",
        "INSERT INTO public.plants (slug, common_name, care_summary, is_published)",
        f"VALUES ('{esc(slug)}', '{esc(name)}',",
        f"  'Draft species shell — {varieties} cultivars in import queue. Curate in GM Interface.', false)",
        "ON CONFLICT (slug) DO NOTHING;",
        "",
    ]


def collect_slugs(mode: str) -> list[str]:
    if mode == "all":
        return sorted(p.stem for p in PAYLOADS.glob("*.json"))
    return list(PRIORITY)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate draft plants SQL from import payloads")
    parser.add_argument(
        "--all",
        action="store_true",
        help="All payload JSON files (default: kitchen priority list only)",
    )
    args = parser.parse_args()
    mode = "all" if args.all else "priority"
    out_name = "garden-v4-14-all-species-shells.sql" if args.all else "garden-v4-13-species-shells-kitchen.sql"
    out = ROOT / "database" / "sql" / out_name

    lines = [
        f"-- {out_name} — draft plant rows for GM Apply pipeline",
        "-- Safe to re-run. Does not publish — set is_published in GM when ready.",
        "",
    ]
    count = 0
    for slug in collect_slugs(mode):
        path = PAYLOADS / f"{slug}.json"
        if not path.exists():
            print(f"Skip missing payload: {slug}")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        lines.extend(shell_lines(slug, data))
        count += 1

    label = out_name.replace(".sql", "")
    lines.append(f"SELECT '{label} ready — {count} draft species' AS status;")
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {count} species shells to {out}")


if __name__ == "__main__":
    main()
