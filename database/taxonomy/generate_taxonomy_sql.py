#!/usr/bin/env python3
"""Parse book-taxonomy.md and generate fix-book-taxonomy.sql + lib/taxonomy-sub-codes.js."""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MD_PATH = Path(__file__).resolve().parent / "book-taxonomy.md"
SQL_PATH = ROOT / "database" / "sql" / "fix-book-taxonomy.sql"
JS_PATH = ROOT / "lib" / "taxonomy-sub-codes.js"

CATEGORY_MAP: dict[int, str] = {
    1: "Rise & Shine",
    2: "The Evening Table",
    3: "Garden & Earth",
    4: "Meat & Fire",
    5: "Ocean & River",
    6: "Slow & Soulful",
    7: "Grains & Comfort",
    8: "Breads & Bakes",
    9: "Sweet Serenades",
    10: "Sips & Stories",
    11: "Preserved & Cherished",
    12: "Feast Days",
    13: "Little Ones",
    14: "Nourish & Heal",
}

# 10 = Sips & Stories (fix-sips-drinks-taxonomy.sql). 3 = Garden & Earth (unchanged until reviewed).
SKIP_SQL_CATEGORY_NUMS = {3, 10}

SIPS_SUB_CODES: dict[str, str] = {
    "Water & Sparkling": "A1",
    "Coffee": "A2",
    "Tea & Infusions": "A3",
    "Hot Chocolate & Warm Comforts": "A4",
    "Juices, Smoothies & Blends": "A5",
    "Milk, Plant Milks & Cultured Drinks": "A6",
    "Sodas, Tonics & Fizz": "A7",
    "Functional & Fermented": "A8",
    "Beer & Brewing": "B1",
    "Wine, Cider & Fermented Fruit": "B2",
    "Spirits & Liqueurs": "B3",
    "Cocktails & Mixed Drinks": "B4",
    "Syrups & Sweeteners": "C1",
    "Cordials, Squash & Concentrates": "C2",
    "Shrubs, Bitters & Infusions": "C3",
    "Garnishes, Ice & Glassware": "C4",
    "Techniques & Reference": "C5",
    "World Drinks": "D1",
    "By Season & Occasion": "D2",
    "For Kids": "D3",
    "Mocktails & Zero-Proof": "D4",
}

# Phase-6 placeholder subcategories (deactivate explicitly; also deactivate any not in new taxonomy).
PHASE6_PLACEHOLDERS: dict[str, list[str]] = {
    "Garden & Earth": ["Vegetables", "Fruits", "Herbs & Greens", "Legumes & Pulses"],
    "Rise & Shine": ["Breakfast", "Brunch"],
    "The Evening Table": ["Mains", "Sides"],
    "Meat & Fire": ["Beef", "Poultry", "Lamb"],
    "Ocean & River": ["Fish", "Shellfish"],
    "Sweet Serenades": ["Cakes", "Pastries"],
    "Little Ones": ["Baby Food", "Family Favourites"],
}

RE_CATEGORY = re.compile(r"^(\d+)\.\s+(.+)$")
RE_PART = re.compile(r"^PART\s+([A-Z])\s+[—\-]\s+(.+)$", re.IGNORECASE)
RE_SUB = re.compile(r"^([A-Z])(\d+)\.\s+(.+)$")


@dataclass
class Division:
    name: str


@dataclass
class Subcategory:
    code: str
    name: str
    sort_order: int
    divisions: list[Division] = field(default_factory=list)


@dataclass
class Category:
    num: int
    title: str
    db_name: str
    subs: list[Subcategory] = field(default_factory=list)


def sort_order_for_sub(part_letter: str, sub_num: int) -> int:
    part_index = ord(part_letter.upper()) - ord("A") + 1
    return part_index * 100 + sub_num * 10


def is_skip_line(line: str) -> bool:
    if not line.strip():
        return True
    if line.startswith("See "):
        return True
    if RE_CATEGORY.match(line):
        return True
    if RE_PART.match(line):
        return True
    if RE_SUB.match(line):
        return True
    return False


def division_subtitle(name: str) -> str:
    for sep in (" / ", " (", ", "):
        if sep in name:
            return name.split(sep, 1)[0].strip()
    return ""


def sql_str(value: str) -> str:
    return value.replace("'", "''")


def parse_taxonomy(text: str) -> tuple[list[Category], list[str]]:
    warnings: list[str] = []
    categories: list[Category] = []
    current_cat: Category | None = None
    current_part_letter: str | None = None
    current_part_title: str | None = None
    current_sub: Subcategory | None = None
    seen_part = False
    in_category_intro = False

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()
        if not stripped:
            continue

        cat_match = RE_CATEGORY.match(stripped)
        if cat_match:
            num = int(cat_match.group(1))
            title = cat_match.group(2).strip()
            db_name = CATEGORY_MAP.get(num)
            if not db_name:
                warnings.append(f"Unknown category number {num}: {title}")
                continue
            current_cat = Category(num=num, title=title, db_name=db_name)
            categories.append(current_cat)
            current_part_letter = None
            current_part_title = None
            current_sub = None
            seen_part = False
            in_category_intro = True
            continue

        if current_cat is None:
            warnings.append(f"Line outside category: {stripped[:80]}")
            continue

        part_match = RE_PART.match(stripped)
        if part_match:
            current_part_letter = part_match.group(1).upper()
            current_part_title = part_match.group(2).strip()
            current_sub = None
            seen_part = True
            in_category_intro = False
            continue

        sub_match = RE_SUB.match(stripped)
        if sub_match:
            if current_part_letter is None:
                warnings.append(
                    f"{current_cat.db_name}: sub '{stripped}' before any PART"
                )
            part_letter = sub_match.group(1).upper()
            sub_num = int(sub_match.group(2))
            sub_name = sub_match.group(3).strip()
            code = f"{part_letter}{sub_num}"
            current_sub = Subcategory(
                code=code,
                name=sub_name,
                sort_order=sort_order_for_sub(part_letter, sub_num),
            )
            current_cat.subs.append(current_sub)
            in_category_intro = False
            continue

        if is_skip_line(stripped):
            continue

        if in_category_intro and not seen_part:
            # Section headers like "All Breakfast Dishes" — not divisions.
            continue

        if current_sub is None:
            if current_part_letter is None:
                warnings.append(
                    f"{current_cat.db_name}: orphan line '{stripped[:60]}'"
                )
                continue
            # PART without explicit A1 — synthesize sub from PART title (e.g. Tag System).
            sub_name = current_part_title or f"Part {current_part_letter}"
            code = f"{current_part_letter}1"
            current_sub = Subcategory(
                code=code,
                name=sub_name,
                sort_order=sort_order_for_sub(current_part_letter, 1),
            )
            current_cat.subs.append(current_sub)
            warnings.append(
                f"{current_cat.db_name}: synthesized sub '{sub_name}' ({code}) for PART {current_part_letter}"
            )

        current_sub.divisions.append(Division(name=stripped))

    return categories, warnings


def generate_sql(categories: list[Category]) -> str:
    lines: list[str] = [
        "-- fix-book-taxonomy.sql",
        "-- Book taxonomy (categories 1–2, 4–9, 11–14). Garden & Earth and Sips & Stories unchanged.",
        "-- Generated by database/taxonomy/generate_taxonomy_sql.py — safe to re-run.",
        "",
    ]

    active_categories = [c for c in categories if c.num not in SKIP_SQL_CATEGORY_NUMS]

    for cat in active_categories:
        db = cat.db_name
        new_sub_names = [s.name for s in cat.subs]
        placeholders = PHASE6_PLACEHOLDERS.get(db, [])

        lines.append(f"-- ── {db} ─────────────────────────────────────────────────────────────")
        lines.append("")

        if placeholders:
            quoted = ", ".join(f"'{sql_str(n)}'" for n in placeholders)
            lines.append(
                f"UPDATE public.recipe_subcategories SET is_active = false\n"
                f"WHERE category = '{sql_str(db)}'\n"
                f"  AND name IN ({quoted});"
            )
            lines.append("")

        if new_sub_names:
            quoted_new = ", ".join(f"'{sql_str(n)}'" for n in new_sub_names)
            lines.append(
                f"UPDATE public.recipe_subcategories SET is_active = false\n"
                f"WHERE category = '{sql_str(db)}'\n"
                f"  AND name NOT IN ({quoted_new});"
            )
            lines.append("")

        if cat.subs:
            lines.append(
                "INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES"
            )
            sub_rows: list[str] = []
            for sub in cat.subs:
                sub_rows.append(
                    f"  ('{sql_str(db)}', '{sql_str(sub.name)}', {sub.sort_order}, true)"
                )
            lines.append(",\n".join(sub_rows))
            lines.append("ON CONFLICT (category, name) DO UPDATE SET")
            lines.append("  sort_order = EXCLUDED.sort_order,")
            lines.append("  is_active = EXCLUDED.is_active;")
            lines.append("")

    lines.append("-- ── Divisions ─────────────────────────────────────────────────────────────────")
    lines.append("")
    lines.append(
        "INSERT INTO public.recipe_divisions (category, subcategory, name, emoji, subtitle, description, sort_order, is_active) VALUES"
    )

    div_rows: list[str] = []
    for cat in active_categories:
        for sub in cat.subs:
            for idx, div in enumerate(sub.divisions, start=1):
                subtitle = division_subtitle(div.name)
                subtitle_sql = f"'{sql_str(subtitle)}'" if subtitle else "''"
                div_rows.append(
                    f"  ('{sql_str(cat.db_name)}', '{sql_str(sub.name)}', "
                    f"'{sql_str(div.name)}', '🍽', {subtitle_sql}, "
                    f"'{sql_str(div.name)}', {idx}, true)"
                )

    if div_rows:
        lines.append(",\n".join(div_rows))
    lines.append("ON CONFLICT (category, subcategory, name) DO UPDATE SET")
    lines.append("  sort_order = EXCLUDED.sort_order,")
    lines.append("  is_active = true,")
    lines.append("  subtitle = EXCLUDED.subtitle,")
    lines.append("  description = EXCLUDED.description;")
    lines.append("")

    lines.append("-- Verify")
    lines.append("SELECT category, count(*) FILTER (WHERE kind = 'sub') AS subs,")
    lines.append("       count(*) FILTER (WHERE kind = 'div') AS divisions")
    lines.append("FROM (")
    lines.append("  SELECT category, 'sub' AS kind FROM public.recipe_subcategories")
    lines.append("  WHERE is_active = true AND category NOT IN ('Sips & Stories', 'Garden & Earth')")
    lines.append("  UNION ALL")
    lines.append("  SELECT category, 'div' FROM public.recipe_divisions")
    lines.append("  WHERE is_active = true AND category NOT IN ('Sips & Stories', 'Garden & Earth')")
    lines.append(") t")
    lines.append("GROUP BY category")
    lines.append("ORDER BY category;")

    return "\n".join(lines) + "\n"


def generate_js(categories: list[Category]) -> str:
    mapping: dict[str, dict[str, str]] = {}
    for cat in categories:
        if cat.num in SKIP_SQL_CATEGORY_NUMS:
            continue
        mapping[cat.db_name] = {sub.name: sub.code for sub in cat.subs}
    mapping["Sips & Stories"] = dict(SIPS_SUB_CODES)

    body = json.dumps(mapping, indent=2, ensure_ascii=False)
    return f"window.TAXONOMY_SUB_CODES = {body};\n"


def main() -> int:
    text = MD_PATH.read_text(encoding="utf-8")
    categories, warnings = parse_taxonomy(text)

    SQL_PATH.parent.mkdir(parents=True, exist_ok=True)
    JS_PATH.parent.mkdir(parents=True, exist_ok=True)

    SQL_PATH.write_text(generate_sql(categories), encoding="utf-8")
    JS_PATH.write_text(generate_js(categories), encoding="utf-8")

    print(f"Wrote {SQL_PATH}")
    print(f"Wrote {JS_PATH}")
    print()
    print("Counts per category (subs, divisions):")
    for cat in categories:
        if cat.num in SKIP_SQL_CATEGORY_NUMS:
            if cat.num == 10:
                print(f"  [{cat.num:2d}] {cat.db_name}: SKIPPED (see fix-sips-drinks-taxonomy.sql)")
            elif cat.num == 3:
                print(f"  [{cat.num:2d}] {cat.db_name}: SKIPPED (unchanged — review in progress)")
            else:
                print(f"  [{cat.num:2d}] {cat.db_name}: SKIPPED")
            continue
        div_count = sum(len(s.divisions) for s in cat.subs)
        print(f"  [{cat.num:2d}] {cat.db_name}: {len(cat.subs)} subs, {div_count} divisions")

    if warnings:
        print()
        print(f"Parse warnings ({len(warnings)}):")
        for w in warnings:
            print(f"  - {w}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
