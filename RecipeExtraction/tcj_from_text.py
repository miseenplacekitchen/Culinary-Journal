"""Turn plain recipe text (PDF, Word, transcript) into TCJ JSON envelopes."""

from __future__ import annotations

import re
from typing import Any

from tcj_extract import (
    build_structured,
    infer_sub_category,
    segment_article_text,
)


def slugify(text: str, max_len: int = 80) -> str:
    slug = re.sub(r"[^\w\-]+", "-", (text or "recipe").lower()).strip("-")
    return (slug[:max_len] or "recipe").strip("-")


MEASURED_INGREDIENT = re.compile(
    r"\d+\s*(?:g|kg|mg|oz|lb|lbs|ml|l|litre|liter|litres|liters|cup|cups|tbsp|tsp|"
    r"tablespoon|teaspoon|pint|pints|clove|cloves|sprig|sprigs|piece|pieces|slice|slices|"
    r"can|cans|pinch|handful)\b|\b\d+\s+(?:eggs?|lemons?|onions?|cloves?)\b",
    re.I,
)


def _ingredient_items(structured: dict[str, Any]) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for block in structured.get("ingredients") or []:
        items.extend(block.get("items") or [])
    return items


def count_measured_ingredients(structured: dict[str, Any]) -> int:
    total = 0
    for item in _ingredient_items(structured):
        blob = f"{item.get('qty', '')} {item.get('unit', '')} {item.get('ingredient', '')}"
        if MEASURED_INGREDIENT.search(blob):
            total += 1
    return total


def looks_like_glossary_or_index(title: str, text: str, structured: dict[str, Any]) -> bool:
    title_clean = (title or "").strip()
    lower = title_clean.lower()
    body = (text or "").lower()

    if "glossary" in lower or "indd" in lower:
        return True
    if re.search(r"\bi\.\s*title:|\bii\.\s*series:", title_clean, re.I):
        return True
    if lower.startswith("contents") or lower.startswith("index"):
        return True

    measured = count_measured_ingredients(structured)
    if measured < 2:
        prose_items = 0
        for item in _ingredient_items(structured):
            ing = str(item.get("ingredient") or "")
            if len(ing) > 70 or ing.count(".") >= 1:
                prose_items += 1
        if prose_items >= 2:
            return True

    method_steps = []
    for block in structured.get("method") or []:
        for step in block.get("steps") or []:
            if isinstance(step, str):
                text_step = step.strip()
            else:
                text_step = str(step.get("text") or "").strip()
            if text_step:
                method_steps.append(text_step)

    if method_steps and measured < 2:
        return True

    if method_steps and len(method_steps) <= 6:
        method_blob = " ".join(method_steps).lower()
        ingredient_blob = " ".join(
            str(item.get("ingredient") or "") for item in _ingredient_items(structured)
        ).lower()
        if ingredient_blob and (
            method_blob[:80] == ingredient_blob[:80] or method_blob in ingredient_blob
        ):
            return True

    if re.match(r"^\d+\.\s+[A-Za-z][^.]{0,55}$", title_clean) and measured < 3:
        return True

    return False


def passes_document_quality(structured: dict[str, Any], title: str, text: str, import_path: str) -> tuple[bool, str]:
    ing_count = sum(len(s.get("items") or []) for s in structured.get("ingredients") or [])
    step_count = sum(len(s.get("steps") or []) for s in structured.get("method") or [])
    name = (structured.get("recipe_name") or "").strip()

    if ing_count < 2 or step_count < 2 or name == "Untitled Recipe":
        return False, f"quality gate: {ing_count} ingredients, {step_count} steps"

    if import_path in {"book-batch", "word-batch", "document-batch"}:
        measured = count_measured_ingredients(structured)
        min_measured = 2 if re.search(r"Yield:\s*\d", text or "", re.I) else 3
        if measured < min_measured:
            return False, f"quality gate: only {measured} measured ingredients (need {min_measured}+)"
        if looks_like_glossary_or_index(name, text, structured):
            return False, "quality gate: glossary/index page"

    return True, ""


def split_document_into_recipes(text: str) -> list[dict[str, str]]:
    """Split a cookbook document into recipe-sized chunks."""
    text = re.sub(r"\r\n?", "\n", text or "").strip()
    if not text:
        return []

    parts = re.split(
        r"\n(?=(?:#{1,3}\s+|\d+[\.\)]\s+[A-Z]|(?:Ingredients|INGREDIENTS|Method|METHOD)\s*:?\s*\n))",
        text,
    )
    chunks: list[dict[str, str]] = []
    for part in parts:
        body = part.strip()
        if len(body) < 80:
            continue
        lines = [ln.strip() for ln in body.splitlines() if ln.strip()]
        title = ""
        for line in lines[:8]:
            if 3 < len(line) < 120 and not re.match(r"^(ingredients?|method)\b", line, re.I):
                title = re.sub(r"^#+\s*", "", line).strip()
                break
        if not title:
            title = lines[0][:100] if lines else "Untitled Recipe"
        chunks.append({"title": title, "body": body})

    if not chunks and len(text) > 80:
        chunks.append({"title": "Untitled Recipe", "body": text})
    return chunks


def structure_text_to_envelope(
    text: str,
    *,
    source_id: str,
    source_label: str,
    credit_name: str = "",
    credit_url: str = "",
    import_path: str = "document-batch",
    title_hint: str = "",
) -> dict[str, Any]:
    seg = segment_article_text(text)
    title = title_hint or seg.get("title") or ""
    structured = build_structured(
        title=title,
        ingredient_lines=seg.get("ingredients") or [],
        method_steps=seg.get("method") or [],
        source_url=credit_url or source_id,
        meta={"author": credit_name},
    )
    if title_hint:
        structured["recipe_name"] = title_hint
    if source_label:
        structured["introduction"] = f"Imported from {source_label}."
    if structured.get("category") == "Sips & Stories" and not structured.get("sub_category"):
        sub = infer_sub_category(structured["recipe_name"], seg.get("ingredients") or [])
        if sub:
            structured["sub_category"] = sub

    ing_count = sum(len(s.get("items") or []) for s in structured.get("ingredients") or [])
    step_count = sum(len(s.get("steps") or []) for s in structured.get("method") or [])
    ok, reason = passes_document_quality(structured, title, text, import_path)

    return {
        "ok": ok,
        "skipped": not ok,
        "reason": reason or None,
        "schema_version": "tcj-website-v1",
        "source_url": credit_url or source_id,
        "source_id": source_id,
        "import_path": import_path,
        "host": source_label,
        "extractor": import_path,
        "extractor_version": "tcj-document-v1",
        "parser_version": "website-batch-v1",
        "warnings": [],
        "structured": structured,
        "paste_snapshot": text[:12000],
        "source_display_name": source_label,
    }
