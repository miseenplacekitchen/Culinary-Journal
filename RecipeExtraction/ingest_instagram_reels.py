#!/usr/bin/env python3
"""
Structure reel transcripts (MyCookbook/reels/*.md) and insert pending rows into submitted_recipes.

Environment variables (never hardcode secrets):
  GROQ_API_KEY              — LLM structuring (chat completions)
  SUPABASE_URL              — e.g. https://xxxx.supabase.co
  SUPABASE_SERVICE_ROLE_KEY — service role (bypasses RLS for trusted batch ingest)
  TCJ_INGEST_USER_ID        — uuid of the owning auth.users row for submitted_recipes.user_id

Usage:
  python ingest_instagram_reels.py --dry-run --limit 1
  python ingest_instagram_reels.py --reel-id DA5IcnhADHb
  python ingest_instagram_reels.py --limit 10
  python ingest_instagram_reels.py --skip-ingested
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from groq import Groq
from supabase import Client, create_client

BASE_DIR = Path(__file__).resolve().parent
COOKBOOK_DIR = BASE_DIR / "MyCookbook" / "reels"
INGESTED_LOG = COOKBOOK_DIR / "_ingested.jsonl"
FAILURES_LOG = COOKBOOK_DIR / "_ingest_failures.jsonl"
STRUCTURE_MODEL = "llama-3.3-70b-versatile"
PARSER_VERSION = "ingest-recipes-v1"
EXTRACTOR_VERSION = "groq-llama-3.3-70b-json"

from tcj_ingest import TCJ_CATEGORIES, normalize_choice, normalize_structured, normalize_tcj_category

SPICE_LEVELS = (
    "Not Applicable",
    "Mild",
    "Medium",
    "Hot",
    "Very Hot",
    "Extremely Hot",
)

SWEET_LEVELS = (
    "Not Applicable",
    "Subtly Sweet",
    "Lightly Sweet",
    "Sweet",
    "Very Sweet",
    "Extremely Sweet",
)

STRUCTURE_PROMPT = f"""You are a recipe data extractor for The Culinary Journal.
Given an Instagram reel URL, optional caption, and English audio transcript, return ONLY valid JSON
(no markdown fences) matching this exact schema:

{{
  "recipe_name": "string — concise dish name",
  "category": "one of: {", ".join(TCJ_CATEGORIES)}",
  "introduction": "1-2 sentence summary of the dish",
  "prep_time_minutes": 0,
  "cook_time_minutes": 0,
  "servings": 1,
  "spice_level": "one of: {", ".join(SPICE_LEVELS)}",
  "sweet_level": "one of: {", ".join(SWEET_LEVELS)}",
  "origin_continent": "string or empty",
  "origin_country": "string or empty",
  "ingredients": [
    {{
      "section": "string — e.g. Ingredients, For Marinade, or empty",
      "items": [
        {{
          "qty": "string",
          "unit": "string",
          "ingredient": "string",
          "note": "string",
          "category": ""
        }}
      ]
    }}
  ],
  "method": [
    {{
      "section": "string — e.g. PREP WORK, DIRECTIONS, or empty",
      "steps": [
        {{ "title": "string or empty", "text": "string" }}
      ]
    }}
  ],
  "cooking_notes": "string or empty — tips not covered in steps",
  "credit_name": "string or empty — creator name if mentioned",
  "credit_handle": "string or empty — Instagram @handle if mentioned or inferable"
}}

Rules:
- ingredients[].items[] must match submit-recipe.html: qty, unit, ingredient, note, category (category may be "").
- method[].steps[] must use {{ title, text }} objects; title may be empty.
- Prefer at least 2 ingredient items and 2 method steps when the source supports it.
- Use the transcript for quantities, steps, and technique; use caption for dish name hints.
- Do not invent ingredients or steps not grounded in the source text.
- Pick the single best TCJ category for the dish (not a geographic region).
- Times and servings: use 0 or 1 when unknown; only set non-zero when explicitly stated.
- Default spice_level and sweet_level to "Not Applicable" unless clearly indicated.
"""


def parse_markdown(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    source = ""
    caption = ""
    translation = ""

    source_match = re.search(r"\*\*Source:\*\*\s*(.+)", text)
    if source_match:
        source = source_match.group(1).strip()

    caption_match = re.search(
        r"## Caption\s*\n+(.*?)(?=\n## English Translation|\Z)",
        text,
        re.S,
    )
    if caption_match:
        caption = caption_match.group(1).strip()

    translation_match = re.search(r"## English Translation\s*\n+(.*)\Z", text, re.S)
    if translation_match:
        translation = translation_match.group(1).strip()

    return {
        "source": source,
        "caption": caption,
        "translation": translation,
        "reel_id": path.stem,
    }


def coerce_int(value: Any, default: int = 0) -> int:
    if value is None or value == "":
        return default
    try:
        return max(0, int(float(str(value).strip())))
    except (TypeError, ValueError):
        return default


def normalize_choice(value: Any, allowed: tuple[str, ...], default: str) -> str:
    if not value:
        return default
    text = str(value).strip()
    if text in allowed:
        return text
    lowered = text.lower()
    for option in allowed:
        if option.lower() == lowered:
            return option
    return default


def normalize_ingredients(raw: Any) -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        return []
    sections: list[dict[str, Any]] = []
    for block in raw:
        if not isinstance(block, dict):
            continue
        section_name = str(block.get("section") or "").strip()
        items_in: list[dict[str, Any]] = []
        for item in block.get("items") or []:
            if not isinstance(item, dict):
                continue
            ingredient = str(item.get("ingredient") or "").strip()
            if not ingredient:
                continue
            items_in.append(
                {
                    "qty": str(item.get("qty") or "").strip(),
                    "unit": str(item.get("unit") or "").strip(),
                    "ingredient": ingredient,
                    "note": str(item.get("note") or "").strip(),
                    "category": str(item.get("category") or "").strip(),
                }
            )
        if items_in or section_name:
            sections.append({"section": section_name, "items": items_in})
    return sections


def normalize_method(raw: Any) -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        return []
    sections: list[dict[str, Any]] = []
    for block in raw:
        if not isinstance(block, dict):
            continue
        section_name = str(block.get("section") or "").strip()
        steps_in: list[dict[str, str]] = []
        for step in block.get("steps") or []:
            if not isinstance(step, dict):
                continue
            title = str(step.get("title") or "").strip()
            text = str(step.get("text") or step.get("body") or "").strip()
            if title or text:
                steps_in.append({"title": title, "text": text})
        if steps_in or section_name:
            sections.append({"section": section_name, "steps": steps_in})
    return sections


def normalize_structured(raw: dict[str, Any]) -> dict[str, Any]:
    recipe_name = str(raw.get("recipe_name") or "").strip() or "Untitled Recipe"
    return {
        "recipe_name": recipe_name,
        "category": normalize_tcj_category(
            normalize_choice(raw.get("category"), TCJ_CATEGORIES, "The Grain Field")
        ),
        "introduction": str(raw.get("introduction") or "").strip(),
        "prep_time_minutes": coerce_int(raw.get("prep_time_minutes")),
        "cook_time_minutes": coerce_int(raw.get("cook_time_minutes")),
        "servings": max(1, coerce_int(raw.get("servings"), default=1)),
        "spice_level": normalize_choice(raw.get("spice_level"), SPICE_LEVELS, "Not Applicable"),
        "sweet_level": normalize_choice(raw.get("sweet_level"), SWEET_LEVELS, "Not Applicable"),
        "origin_continent": str(raw.get("origin_continent") or "").strip(),
        "origin_country": str(raw.get("origin_country") or "").strip(),
        "ingredients": normalize_ingredients(raw.get("ingredients")),
        "method": normalize_method(raw.get("method")),
        "cooking_notes": str(raw.get("cooking_notes") or "").strip(),
        "credit_name": str(raw.get("credit_name") or "").strip(),
        "credit_handle": str(raw.get("credit_handle") or "").strip(),
    }


def structure_recipe(client: Groq, fields: dict[str, str], retries: int = 2) -> dict[str, Any]:
    user_content = (
        f"Reel ID: {fields.get('reel_id', '')}\n"
        f"Source URL: {fields.get('source', '')}\n\n"
        f"Caption:\n{fields.get('caption', '') or '(none)'}\n\n"
        f"Transcript:\n{fields.get('translation', '')}"
    )
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            response = client.chat.completions.create(
                model=STRUCTURE_MODEL,
                messages=[
                    {"role": "system", "content": STRUCTURE_PROMPT},
                    {"role": "user", "content": user_content},
                ],
                response_format={"type": "json_object"},
                temperature=0.1,
            )
            raw = response.choices[0].message.content or "{}"
            parsed = json.loads(raw)
            if not isinstance(parsed, dict):
                raise ValueError("LLM response was not a JSON object")
            return normalize_structured(parsed)
        except Exception as exc:  # noqa: BLE001 — retry Groq rate limits / malformed JSON
            last_error = exc
            if attempt < retries:
                time.sleep(2**attempt)
    raise last_error or RuntimeError("Groq structuring failed")


def build_submitted_recipes_row(
    structured: dict[str, Any],
    fields: dict[str, str],
    user_id: str,
) -> dict[str, Any]:
    source_url = fields.get("source") or ""
    now_iso = datetime.now(timezone.utc).isoformat()
    credit_handle = structured.get("credit_handle") or ""
    if credit_handle and not credit_handle.startswith("@"):
        credit_handle = f"@{credit_handle.lstrip('@')}"

    row: dict[str, Any] = {
        "user_id": user_id,
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
        "source_type": "From Somewhere Else",
        "credit_url": source_url or None,
        "credit_name": structured.get("credit_name") or None,
        "credit_handle": credit_handle or None,
        "status": "pending",
        "visibility": "Public",
        "paste_text": fields.get("translation") or None,
        "source_url": source_url or None,
        "import_source_url": source_url or None,
        "import_path": "instagram-audio-whisper",
        "import_extractor": EXTRACTOR_VERSION,
        "parser_version": PARSER_VERSION,
        "extractor_version": EXTRACTOR_VERSION,
        "imported_at": now_iso,
        "import_paste_snapshot": (fields.get("caption") or fields.get("translation") or "")[:12000] or None,
        "import_attribution_notice": (
            "Imported from Instagram reel audio transcript via RecipeExtraction pipeline. "
            f"Original reel: {source_url or fields.get('reel_id', '')}. Pending admin review."
        ),
        "import_warnings": [],
    }

    if structured.get("origin_continent"):
        row["origin_continent"] = structured["origin_continent"]
    if structured.get("origin_country"):
        row["origin_country"] = structured["origin_country"]

    return row


def load_ingested_ids() -> set[str]:
    ids: set[str] = set()
    if not INGESTED_LOG.is_file():
        return ids
    for line in INGESTED_LOG.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ids.add(json.loads(line).get("reel_id", ""))
        except json.JSONDecodeError:
            continue
    return ids


def log_failure(reel_id: str, error: str) -> None:
    COOKBOOK_DIR.mkdir(parents=True, exist_ok=True)
    with FAILURES_LOG.open("a", encoding="utf-8") as handle:
        handle.write(
            json.dumps(
                {
                    "reel_id": reel_id,
                    "error": error,
                    "at": datetime.now(timezone.utc).isoformat(),
                }
            )
            + "\n"
        )


def log_ingested(reel_id: str, inserted_id: str | None, recipe_name: str) -> None:
    COOKBOOK_DIR.mkdir(parents=True, exist_ok=True)
    with INGESTED_LOG.open("a", encoding="utf-8") as handle:
        handle.write(
            json.dumps(
                {
                    "reel_id": reel_id,
                    "id": inserted_id,
                    "recipe_name": recipe_name,
                    "at": datetime.now(timezone.utc).isoformat(),
                }
            )
            + "\n"
        )


def source_already_ingested(supabase: Client, source_url: str) -> bool:
    if not source_url:
        return False
    result = (
        supabase.table("submitted_recipes")
        .select("id")
        .eq("import_source_url", source_url)
        .limit(1)
        .execute()
    )
    return bool(result.data)


def resolve_markdown_files(args: argparse.Namespace) -> list[Path]:
    if args.reel_id:
        path = COOKBOOK_DIR / f"{args.reel_id}.md"
        if not path.is_file():
            raise FileNotFoundError(f"Markdown file not found: {path}")
        return [path]

    md_files = sorted(p for p in COOKBOOK_DIR.glob("*.md") if not p.stem.startswith("_"))
    if args.skip_ingested:
        ingested = load_ingested_ids()
        md_files = [p for p in md_files if p.stem not in ingested]
    if args.limit:
        md_files = md_files[: args.limit]
    return md_files


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Stage 2: structure and ingest MyCookbook files.")
    parser.add_argument("--limit", type=int, default=None, help="Process at most N markdown files.")
    parser.add_argument(
        "--reel-id",
        type=str,
        default=None,
        help="Process a single reel by markdown stem, e.g. DA5IcnhADHb.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Structure only; do not insert.")
    parser.add_argument(
        "--skip-ingested",
        action="store_true",
        help="Skip reel IDs listed in MyCookbook/_ingested.jsonl.",
    )
    parser.add_argument(
        "--skip-duplicates",
        action="store_true",
        help="Skip when import_source_url already exists in submitted_recipes.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    groq_key = os.environ.get("GROQ_API_KEY")
    supabase_url = os.environ.get("SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    user_id = os.environ.get("TCJ_INGEST_USER_ID")

    if not groq_key:
        print("Error: set GROQ_API_KEY", file=sys.stderr)
        return 1
    if not args.dry_run and (not supabase_url or not service_key or not user_id):
        print(
            "Error: set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, and TCJ_INGEST_USER_ID",
            file=sys.stderr,
        )
        return 1

    try:
        md_files = resolve_markdown_files(args)
    except FileNotFoundError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    if not md_files:
        print("No markdown files to process.")
        return 0

    groq = Groq(api_key=groq_key)
    supabase: Client | None = None if args.dry_run else create_client(supabase_url, service_key)

    print(
        f"Processing {len(md_files)} file(s)"
        f"{' (dry-run)' if args.dry_run else ''}..."
    )

    ok = 0
    failed = 0
    skipped = 0

    for path in md_files:
        reel_id = path.stem
        try:
            fields = parse_markdown(path)
            if not fields.get("translation"):
                raise ValueError("Markdown file has no English Translation section")

            if args.skip_duplicates and supabase and source_already_ingested(supabase, fields.get("source", "")):
                print(f"Skip duplicate {reel_id} ({fields.get('source', '')})")
                skipped += 1
                continue

            structured = structure_recipe(groq, fields)
            row = build_submitted_recipes_row(structured, fields, user_id or "")

            if args.dry_run:
                preview = {
                    "reel_id": reel_id,
                    "recipe_name": row["recipe_name"],
                    "category": row["category"],
                    "ingredient_sections": len(row["ingredients"]),
                    "method_sections": len(row["method"]),
                    "row": row,
                }
                print(json.dumps(preview, indent=2))
                ok += 1
                continue

            assert supabase is not None
            result = supabase.table("submitted_recipes").insert(row).execute()
            inserted_id = result.data[0]["id"] if result.data else None
            log_ingested(reel_id, inserted_id, row["recipe_name"])
            print(f"Ingested {reel_id} -> {inserted_id} ({row['recipe_name']})")
            ok += 1
        except Exception as exc:  # noqa: BLE001 — continue batch on single-file failure
            failed += 1
            log_failure(reel_id, str(exc))
            print(f"Failed {reel_id}: {exc}", file=sys.stderr)

    print(f"Done. ok={ok} failed={failed} skipped={skipped}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
