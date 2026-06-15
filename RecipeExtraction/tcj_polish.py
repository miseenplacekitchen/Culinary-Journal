"""Groq-powered TCJ recipe cleanup for batch imports (books, websites)."""

from __future__ import annotations

import json
import re
import sys
import time
from typing import Any

from groq import Groq

from tcj_ingest import (
    SPICE_LEVELS,
    SWEET_LEVELS,
    TCJ_CATEGORIES,
    normalize_structured,
)

POLISH_MODEL = "llama-3.3-70b-versatile"
POLISH_VERSION = "tcj-groq-polish-v1"

LIGATURES = str.maketrans({"ﬁ": "fi", "ﬂ": "fl", "ﬀ": "ff", "ﬃ": "ffi", "ﬄ": "ffl"})

POLISH_PROMPT = f"""You are a recipe editor for The Culinary Journal (TCJ).
You receive messy extracted recipe data from a cookbook or website. Return ONLY valid JSON
(no markdown fences) that matches this schema:

{{
  "recipe_name": "string — clean Title Case dish name, no page numbers or section codes",
  "category": "one of: {", ".join(TCJ_CATEGORIES)}",
  "introduction": "1-2 sentences describing the dish in warm, professional prose",
  "prep_time_minutes": 0,
  "cook_time_minutes": 0,
  "servings": 1,
  "spice_level": "one of: {", ".join(SPICE_LEVELS)}",
  "sweet_level": "one of: {", ".join(SWEET_LEVELS)}",
  "origin_continent": "string or empty",
  "origin_country": "string or empty",
  "ingredients": [
    {{
      "section": "Ingredients or subsection name",
      "items": [
        {{ "qty": "string", "unit": "string", "ingredient": "string", "note": "string", "category": "" }}
      ]
    }}
  ],
  "method": [
    {{
      "section": "DIRECTIONS or PREP WORK",
      "steps": [ {{ "title": "", "text": "string — clear formal step" }} ]
    }}
  ],
  "cooking_notes": "optional tips string or empty"
}}

Rules:
- Split every ingredient into qty, unit, ingredient, note. Example: "Long-grain rice 300 g (10 oz)"
  → qty "300", unit "g", ingredient "Long-grain rice", note "10 oz".
- Use governed-style ingredient names (e.g. "Ghee", "Long-Grain Rice", "Aubergine", "Ground Turmeric").
- Rewrite procedure steps in clear, formal English (complete sentences, active voice). Keep the same cooking logic.
- Remove PDF artefacts: "POUL TRY 81", page numbers, run-on titles, InDesign junk.
- Infer origin_country from cuisine when obvious (e.g. Nasi Lemak → Malaysia, Paella → Spain).
- Pick the single best TCJ category. Desserts/puddings → Sweet Serenades; soups → Slow & Soulful or Rise & Shine.
- Use servings/times from source when stated; otherwise keep sensible defaults from Serves line.
- Do not invent ingredients or steps not supported by the source.
- Preserve sub-sections (e.g. "Spice Paste", "Garnishing") as separate ingredient sections when present.
"""


def flatten_recipe_for_prompt(row: dict[str, Any]) -> str:
    """Build a text bundle from a submitted_recipes row for the LLM."""
    parts: list[str] = []
    name = str(row.get("recipe_name") or "").translate(LIGATURES)
    parts.append(f"Recipe name: {name}")
    if row.get("credit_name"):
        parts.append(f"Source book: {row.get('credit_name')}")
    if row.get("import_source_url"):
        parts.append(f"Source URL: {row.get('import_source_url')}")
    if row.get("servings"):
        parts.append(f"Serves: {row.get('servings')}")
    if row.get("introduction"):
        parts.append(f"Introduction: {row.get('introduction')}")
    if row.get("import_paste_snapshot"):
        parts.append(f"Raw extract:\n{str(row.get('import_paste_snapshot'))[:8000]}")

    ingredients = row.get("ingredients")
    if ingredients:
        parts.append("Ingredients (messy JSON — fix and split):")
        parts.append(json.dumps(ingredients, ensure_ascii=False, indent=2)[:6000])

    method = row.get("method")
    if method:
        parts.append("Method (rewrite for clarity):")
        parts.append(json.dumps(method, ensure_ascii=False, indent=2)[:6000])

    if row.get("cooking_notes"):
        parts.append(f"Notes: {row.get('cooking_notes')}")

    return "\n\n".join(parts)


def flatten_envelope_for_prompt(envelope: dict[str, Any]) -> str:
    structured = envelope.get("structured") or {}
    row = {
        "recipe_name": structured.get("recipe_name"),
        "credit_name": structured.get("credit_name") or envelope.get("host"),
        "import_source_url": envelope.get("source_url"),
        "servings": structured.get("servings"),
        "introduction": structured.get("introduction"),
        "import_paste_snapshot": envelope.get("paste_snapshot") or structured.get("introduction"),
        "ingredients": structured.get("ingredients"),
        "method": structured.get("method"),
        "cooking_notes": structured.get("cooking_notes"),
    }
    return flatten_recipe_for_prompt(row)


def _rate_limit_wait_seconds(exc: Exception) -> int | None:
    msg = str(exc)
    if "429" not in msg and "rate_limit" not in msg.lower():
        return None
    match = re.search(r"try again in (\d+)m([\d.]+)s", msg, re.I)
    if match:
        return int(match.group(1)) * 60 + int(float(match.group(2))) + 5
    match = re.search(r"try again in ([\d.]+)s", msg, re.I)
    if match:
        return int(float(match.group(1))) + 5
    return 120


def polish_with_groq(client: Groq, source_text: str, retries: int = 3) -> dict[str, Any]:
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            response = client.chat.completions.create(
                model=POLISH_MODEL,
                messages=[
                    {"role": "system", "content": POLISH_PROMPT},
                    {"role": "user", "content": source_text},
                ],
                response_format={"type": "json_object"},
                temperature=0.15,
            )
            raw = response.choices[0].message.content or "{}"
            parsed = json.loads(raw)
            if not isinstance(parsed, dict):
                raise ValueError("LLM response was not a JSON object")
            return normalize_structured(parsed)
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            if attempt >= retries:
                break
            wait = _rate_limit_wait_seconds(exc)
            if wait:
                print(f"  Groq rate limit — waiting {wait}s before retry…", file=sys.stderr)
                time.sleep(min(wait, 600))
            else:
                time.sleep(2**attempt)
    raise last_error or RuntimeError("Groq polish failed")


def collect_unknown_ingredients(
    structured: dict[str, Any],
    known_names: set[str],
    aka_map: dict[str, str],
) -> list[str]:
    """Return ingredient names not in the governed database (case-insensitive)."""
    unknown: list[str] = []
    seen: set[str] = set()
    for block in structured.get("ingredients") or []:
        for item in block.get("items") or []:
            name = str(item.get("ingredient") or "").strip()
            if not name or len(name) < 2:
                continue
            key = name.lower()
            if key in seen:
                continue
            seen.add(key)
            if key in known_names or key in aka_map:
                continue
            unknown.append(name)
    return unknown


def apply_governed_names(
    structured: dict[str, Any],
    canonical_map: dict[str, str],
) -> dict[str, Any]:
    """Rewrite ingredient lines to canonical DB names when we have an exact/AKA match."""
    for block in structured.get("ingredients") or []:
        for item in block.get("items") or []:
            raw = str(item.get("ingredient") or "").strip()
            if not raw:
                continue
            canonical = canonical_map.get(raw.lower())
            if canonical:
                item["ingredient"] = canonical
    return structured


def load_ingredient_index(supabase) -> tuple[set[str], dict[str, str], dict[str, str]]:
    """Fetch governed ingredients for matching. Returns (known_lower, aka→canonical, canonical_map)."""
    known: set[str] = set()
    aka_to_canonical: dict[str, str] = {}
    canonical_map: dict[str, str] = {}

    try:
        offset = 0
        page_size = 1000
        while True:
            result = (
                supabase.table("ingredients")
                .select('"Ingredient Name","Also Known As"')
                .range(offset, offset + page_size - 1)
                .execute()
            )
            rows = result.data or []
            if not rows:
                break
            for row in rows:
                name = str(row.get("Ingredient Name") or "").strip()
                if not name:
                    continue
                canonical_map[name.lower()] = name
                known.add(name.lower())
                aka = str(row.get("Also Known As") or "")
                for part in re.split(r"[,;/]", aka):
                    part = part.strip().lower()
                    if part:
                        aka_to_canonical[part] = name
                        canonical_map[part] = name
            if len(rows) < page_size:
                break
            offset += page_size
    except Exception as exc:  # noqa: BLE001 — service_role may lack SELECT on ingredients
        print(f"  Warning: could not load ingredients ({exc}). Polish continues without DB matching.", file=sys.stderr)

    return known, aka_to_canonical, canonical_map
