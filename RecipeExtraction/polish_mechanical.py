#!/usr/bin/env python3
"""
Mechanical pending cleanup — NO Groq. Titles, governed names, intro, structure.

Usage:
  python polish_mechanical.py --limit 50
  python polish_mechanical.py --dry-run --limit 5
"""

from __future__ import annotations

import argparse
import os
import sys

from supabase import create_client

from tcj_normalize import clean_recipe_title, normalize_recipe_name_in_structured
from tcj_polish import apply_governed_names, collect_unknown_ingredients, load_ingredient_index

MECHANICAL_VERSION = "tcj-mechanical-v1"
BOILERPLATE = "Imported from Personal book collection."


def simple_intro(name: str, category: str, credit: str) -> str:
    src = f" from {credit}" if credit else ""
    return f"{name} — a {category.lower()} recipe{src}, prepared in the TCJ style."


def polish_row(row: dict, canonical_map: dict, known, aka_map) -> dict | None:
    structured = {
        "recipe_name": clean_recipe_title(str(row.get("recipe_name") or "")),
        "category": row.get("category") or "The Evening Table",
        "introduction": row.get("introduction") or "",
        "prep_time_minutes": row.get("prep_time_minutes") or 0,
        "cook_time_minutes": row.get("cook_time_minutes") or 0,
        "servings": row.get("servings") or 1,
        "spice_level": row.get("spice_level") or "Not Applicable",
        "sweet_level": row.get("sweet_level") or "Not Applicable",
        "ingredients": row.get("ingredients") or [],
        "method": row.get("method") or [],
        "cooking_notes": row.get("cooking_notes") or "",
    }
    normalize_recipe_name_in_structured(structured)
    apply_governed_names(structured, canonical_map)
    intro = str(structured.get("introduction") or "").strip()
    if not intro or intro == BOILERPLATE or intro.startswith("Imported from "):
        structured["introduction"] = simple_intro(
            structured["recipe_name"],
            structured["category"],
            str(row.get("credit_name") or ""),
        )
    unknown = collect_unknown_ingredients(structured, known, aka_map)
    ing_count = sum(len(s.get("items") or []) for s in structured.get("ingredients") or [])
    step_count = sum(len(s.get("steps") or []) for s in structured.get("method") or [])
    if ing_count < 2 and step_count < 2:
        return None
    return {
        "recipe_name": structured["recipe_name"],
        "category": structured["category"],
        "introduction": structured["introduction"],
        "ingredients": structured["ingredients"],
        "method": structured["method"],
        "cooking_notes": structured["cooking_notes"],
        "unknown_ingredients": unknown or None,
        "procedure_rewritten": True,
        "import_extractor": MECHANICAL_VERSION,
    }


def main() -> int:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        print("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
        return 1

    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=50)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    sb = create_client(url, key)
    known, aka_map, canonical_map = load_ingredient_index(sb)
    rows = (
        sb.table("submitted_recipes")
        .select("*")
        .eq("status", "pending")
        .order("submitted_at")
        .limit(args.limit)
        .execute()
        .data
        or []
    )

    updated = skipped = 0
    for row in rows:
        patch = polish_row(row, canonical_map, known, aka_map)
        if not patch:
            skipped += 1
            print(f"  skip (empty): {row.get('recipe_name')}")
            continue
        if args.dry_run:
            print(f"  would polish: {patch['recipe_name']}")
        else:
            sb.table("submitted_recipes").update(patch).eq("id", row["id"]).execute()
            print(f"  polished: {patch['recipe_name']}")
        updated += 1

    print(f"Done. polished={updated} skipped={skipped}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
