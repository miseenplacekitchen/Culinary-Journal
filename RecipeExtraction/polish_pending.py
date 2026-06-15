#!/usr/bin/env python3
"""
Groq cleanup for pending batch imports — fixes titles, splits ingredients, rewrites steps.

Requires setup-env.ps1 (SUPABASE_*, GROQ_API_KEY).

Usage:
  python polish_pending.py --dry-run --limit 1
  python polish_pending.py --limit 10
  python polish_pending.py --import-path book-batch
  python polish_pending.py --from-json --limit 5   # polish MyCookbook JSON only (no DB)
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from groq import Groq
from supabase import create_client

from tcj_normalize import clean_recipe_title
from tcj_polish import (
    POLISH_VERSION,
    apply_governed_names,
    collect_unknown_ingredients,
    flatten_envelope_for_prompt,
    flatten_recipe_for_prompt,
    load_ingredient_index,
    polish_with_groq,
)

BASE_DIR = Path(__file__).resolve().parent
MYCOOKBOOK = BASE_DIR / "MyCookbook"
LOG_PATH = MYCOOKBOOK / "books" / "_polished.jsonl"


def _configure_stdio_utf8() -> None:
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if callable(reconfigure):
            try:
                reconfigure(encoding="utf-8", errors="replace")
            except (OSError, ValueError):
                pass


def log_result(record: dict) -> None:
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record) + "\n")


def build_update_row(
    structured: dict,
    *,
    unknown: list[str],
    already_polished: bool,
) -> dict:
    row = {
        "recipe_name": structured["recipe_name"],
        "category": structured["category"],
        "introduction": structured["introduction"],
        "prep_time_minutes": structured["prep_time_minutes"],
        "cook_time_minutes": structured["cook_time_minutes"],
        "servings": structured["servings"],
        "spice_level": structured["spice_level"],
        "sweet_level": structured["sweet_level"],
        "ingredients": structured["ingredients"],
        "method": structured["method"],
        "cooking_notes": structured["cooking_notes"],
        "unknown_ingredients": unknown or None,
        "procedure_rewritten": True,
        "import_extractor": POLISH_VERSION if not already_polished else None,
    }
    if structured.get("origin_continent"):
        row["origin_continent"] = structured["origin_continent"]
    if structured.get("origin_country"):
        row["origin_country"] = structured["origin_country"]
    return {k: v for k, v in row.items() if v is not None}


def polish_db_recipes(args: argparse.Namespace) -> int:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    groq_key = os.environ.get("GROQ_API_KEY")
    if not url or not key or not groq_key:
        print("Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, GROQ_API_KEY", file=sys.stderr)
        return 1

    supabase = create_client(url, key)
    client = Groq(api_key=groq_key)

    print("Loading governed ingredient index…")
    known, aka_map, canonical_map = load_ingredient_index(supabase)
    print(f"  {len(known)} ingredients loaded")

    query = (
        supabase.table("submitted_recipes")
        .select("*")
        .eq("status", args.status)
        .order("submitted_at")
    )
    if args.import_path:
        query = query.eq("import_path", args.import_path)
    if args.recipe_id:
        query = query.eq("id", args.recipe_id)

    result = query.execute()
    rows = result.data or []
    if args.skip_polished:
        rows = [r for r in rows if not r.get("procedure_rewritten")]
    if args.limit:
        rows = rows[: args.limit]

    if not rows:
        print("No matching recipes to polish.")
        return 0

    print(f"Polishing {len(rows)} recipe(s)…{' (dry-run)' if args.dry_run else ''}")
    ok = failed = 0

    for row in rows:
        rid = row.get("id")
        name = row.get("recipe_name") or rid
        try:
            if row.get("procedure_rewritten") and not args.force:
                print(f"Skip already polished: {name}")
                continue

            source_text = flatten_recipe_for_prompt(row)
            structured = polish_with_groq(client, source_text)
            structured = apply_governed_names(structured, canonical_map)
            unknown = collect_unknown_ingredients(structured, known, aka_map)
            update = build_update_row(
                structured,
                unknown=unknown,
                already_polished=bool(row.get("procedure_rewritten")),
            )

            preview = {
                "id": rid,
                "recipe_name": update["recipe_name"],
                "category": update["category"],
                "servings": update["servings"],
                "ingredient_lines": sum(
                    len(b.get("items") or []) for b in update.get("ingredients") or []
                ),
                "step_count": sum(
                    len(b.get("steps") or []) for b in update.get("method") or []
                ),
                "unknown_ingredients": unknown[:8],
            }

            if args.dry_run:
                print(json.dumps(preview, indent=2))
                ok += 1
                continue

            supabase.table("submitted_recipes").update(update).eq("id", rid).execute()
            log_result({"id": rid, "recipe_name": update["recipe_name"], "at": datetime.now(timezone.utc).isoformat()})
            print(f"Polished {update['recipe_name']} ({preview['ingredient_lines']} ingredients, {preview['step_count']} steps)")
            ok += 1
            if args.delay:
                time.sleep(args.delay)
        except Exception as exc:  # noqa: BLE001
            if args.fallback_titles and not args.dry_run:
                new_title = clean_recipe_title(str(row.get("recipe_name") or ""))
                if new_title and new_title != row.get("recipe_name"):
                    supabase.table("submitted_recipes").update({"recipe_name": new_title}).eq("id", rid).execute()
                    print(f"Title-only fix (Groq unavailable): {new_title}", file=sys.stderr)
                    ok += 1
                    continue
            failed += 1
            print(f"Failed {name}: {exc}", file=sys.stderr)

    print(f"Done. ok={ok} failed={failed}")
    if failed and not args.dry_run:
        print("Re-run later to finish — already-polished recipes are skipped.", file=sys.stderr)
    return 1 if failed else 0


def polish_json_files(args: argparse.Namespace) -> int:
    groq_key = os.environ.get("GROQ_API_KEY")
    if not groq_key:
        print("Set GROQ_API_KEY", file=sys.stderr)
        return 1

    client = Groq(api_key=groq_key)
    folder = MYCOOKBOOK / (args.subdir or "books")
    files = sorted(folder.glob("*.json"))
    files = [p for p in files if not p.name.startswith("_")]
    if args.limit:
        files = files[: args.limit]

    ok = failed = 0
    for path in files:
        try:
            envelope = json.loads(path.read_text(encoding="utf-8"))
            source_text = flatten_envelope_for_prompt(envelope)
            structured = polish_with_groq(client, source_text)
            envelope["structured"] = structured
            envelope["polished_at"] = datetime.now(timezone.utc).isoformat()
            envelope["polish_version"] = POLISH_VERSION
            preview = {"file": path.name, "recipe_name": structured["recipe_name"]}
            if args.dry_run:
                print(json.dumps(preview, indent=2))
            else:
                path.write_text(json.dumps(envelope, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
                print(f"Polished JSON {path.name} -> {structured['recipe_name']}")
            ok += 1
            if args.delay:
                time.sleep(args.delay)
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"Failed {path.name}: {exc}", file=sys.stderr)

    print(f"Done. ok={ok} failed={failed}")
    return 1 if failed else 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Groq cleanup for pending TCJ batch imports.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--status", default="pending", help="DB status filter (default: pending)")
    parser.add_argument("--import-path", default="book-batch", help="Filter by import_path (default: book-batch)")
    parser.add_argument("--recipe-id", default=None, help="Polish a single recipe UUID")
    parser.add_argument("--skip-polished", action="store_true", default=True)
    parser.add_argument("--force", action="store_true", help="Re-polish even if procedure_rewritten is set")
    parser.add_argument("--all-pending", action="store_true", help="Ignore import_path filter")
    parser.add_argument("--from-json", action="store_true", help="Polish MyCookbook JSON files instead of DB")
    parser.add_argument("--subdir", default="books")
    parser.add_argument("--delay", type=float, default=1.5, help="Seconds between Groq calls")
    parser.add_argument(
        "--fallback-titles",
        action="store_true",
        default=True,
        help="If Groq fails, at least fix the recipe title (default: on)",
    )
    parser.add_argument("--no-fallback-titles", action="store_true", help="Disable title-only fallback")
    args = parser.parse_args()
    if args.no_fallback_titles:
        args.fallback_titles = False
    if args.all_pending:
        args.import_path = None
    if args.force:
        args.skip_polished = False
    return args


def main() -> int:
    _configure_stdio_utf8()
    args = parse_args()
    if args.from_json:
        return polish_json_files(args)
    return polish_db_recipes(args)


if __name__ == "__main__":
    raise SystemExit(main())
