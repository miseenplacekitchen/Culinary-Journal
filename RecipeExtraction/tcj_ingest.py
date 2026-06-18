"""Shared TCJ recipe schema helpers for batch website ingest (no Groq)."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse


def normalize_host(url: str) -> str:
    host = (urlparse(url).netloc or "").lower()
    if host.startswith("www."):
        host = host[4:]
    return host

TCJ_CATEGORIES = (
    "Garden & Earth",
    "Feather & Flock",
    "Pasture & Hoof",
    "Ocean & River",
    "The Grain Field",
    "Wrapped & Stuffed",
    "Curds, Creams & Eggs",
    "Breads & Bakery",
    "Sweet Serenades",
    "Sips & Stories",
    "Preserved & Pantry",
)

LEGACY_CATEGORY_MAP = {
    "Rise & Shine": "Curds, Creams & Eggs",
    "The Evening Table": "Wrapped & Stuffed",
    "Meat & Fire": "Feather & Flock",
    "Slow & Soulful": "Pasture & Hoof",
    "Grains & Comfort": "The Grain Field",
    "Breads & Bakes": "Breads & Bakery",
    "Preserved & Cherished": "Preserved & Pantry",
    "Little Ones": "Garden & Earth",
    "Feast Days": "Pasture & Hoof",
    "Nourish & Heal": "Garden & Earth",
}


def normalize_tcj_category(raw: str | None) -> str:
    if not raw:
        return "The Grain Field"
    c = str(raw).strip()
    if c in TCJ_CATEGORIES:
        return c
    return LEGACY_CATEGORY_MAP.get(c, "The Grain Field")

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

PARSER_VERSION = "website-batch-v1"
EXTRACTOR_VERSION = "recipe-import-extract-v2"


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
        section_name = str(block.get("section") or block.get("name") or "").strip() or "Ingredients"
        items_in: list[dict[str, Any]] = []
        for item in block.get("items") or []:
            if not isinstance(item, dict):
                continue
            ingredient = str(item.get("ingredient") or item.get("name") or "").strip()
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
        if items_in:
            sections.append({"section": section_name, "items": items_in})
    return sections


def normalize_method(raw: Any) -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        return []
    sections: list[dict[str, Any]] = []
    for block in raw:
        if not isinstance(block, dict):
            continue
        section_name = str(block.get("section") or block.get("name") or "").strip() or "DIRECTIONS"
        steps_in: list[dict[str, str]] = []
        for step in block.get("steps") or []:
            if isinstance(step, str):
                text = step.strip()
                if text:
                    steps_in.append({"title": "", "text": text})
                continue
            if not isinstance(step, dict):
                continue
            title = str(step.get("title") or "").strip()
            text = str(step.get("text") or step.get("body") or "").strip()
            if title or text:
                steps_in.append({"title": title, "text": text})
        if steps_in:
            sections.append({"section": section_name.upper(), "steps": steps_in})
    return sections


def normalize_structured(raw: dict[str, Any]) -> dict[str, Any]:
    recipe_name = str(raw.get("recipe_name") or "").strip() or "Untitled Recipe"
    return {
        "recipe_name": recipe_name,
        "category": normalize_tcj_category(
            normalize_choice(raw.get("category"), TCJ_CATEGORIES, "The Grain Field")
        ),
        "sub_category": str(raw.get("sub_category") or "").strip(),
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


def resolve_import_host(source_url: str) -> str:
    url = (source_url or "").strip()
    if url.startswith("tcj://"):
        tail = url.replace("tcj://", "", 1)
        return tail.split("/")[0] if tail else "document"
    return normalize_host(url)


def build_submitted_recipes_row(
    structured: dict[str, Any],
    *,
    source_url: str,
    user_id: str,
    paste_snapshot: str = "",
    extractor_version: str = EXTRACTOR_VERSION,
    warnings: list[str] | None = None,
    source_display_name: str = "",
    import_path: str = "website-batch",
) -> dict[str, Any]:
    now_iso = datetime.now(timezone.utc).isoformat()
    credit_handle = structured.get("credit_handle") or ""
    if credit_handle and not credit_handle.startswith("@"):
        credit_handle = f"@{credit_handle.lstrip('@')}"

    live_url = (source_url or "").strip()
    source_host = resolve_import_host(live_url)
    credit_name = (structured.get("credit_name") or "").strip() or None
    site_label = (source_display_name or source_host or "recipe website").strip()

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
        "credit_url": live_url or None,
        "credit_name": credit_name,
        "credit_handle": credit_handle or None,
        "status": "pending",
        "visibility": "Public",
        "paste_text": paste_snapshot or None,
        "source_url": live_url or None,
        "import_source_url": live_url or None,
        "import_source_host": source_host or None,
        "import_path": import_path,
        "import_extractor": extractor_version,
        "parser_version": PARSER_VERSION,
        "extractor_version": extractor_version,
        "imported_at": now_iso,
        "import_paste_snapshot": (paste_snapshot or "")[:12000] or None,
        "import_attribution_notice": (
            f"Imported from {site_label}. Live source: {live_url or 'unknown'}. "
            f"Chef credit: {credit_name or site_label}. Pending admin review."
        ),
        "import_warnings": warnings or [],
    }

    if structured.get("origin_continent"):
        row["origin_continent"] = structured["origin_continent"]
    if structured.get("origin_country"):
        row["origin_country"] = structured["origin_country"]
    if structured.get("sub_category"):
        row["sub_category"] = structured["sub_category"]

    return row
