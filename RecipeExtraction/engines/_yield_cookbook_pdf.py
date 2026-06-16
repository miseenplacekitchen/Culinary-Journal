"""Cookbook PDF parsing — Yield: N servings layout (Mouzawak / Lebanese Home Cooking)."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from _cookbook_pdf import clean_pdf_text, read_pdf_pages

YIELD_MARKER = re.compile(r"Yield:\s*([\d\-–—]+)\s*servings?", re.I)
TITLE_ARABIC = re.compile(
    r"(?:^|\n\n)(?P<title>[a-z][^\n]{2,90})\n\((?P<native>[^)]+)\)\n",
    re.I,
)
SECTION_HEADER = re.compile(
    r"^(?:KIBBEH|GRAINS|LEGUMES|VEGETABLES|SAUCES|SWEETS|INTRODUCTION|CONTENTS)\s*$",
    re.I | re.M,
)
ING_SECTION = re.compile(r"^For the .+:$", re.I)
MEASURED = re.compile(
    r"\d+\s*(?:/\d+)?\s*(?:g|kg|oz|ml|l|litre|liter|cup|cups|tbsp|tsp|pound|pounds|ounce|ounces)\b"
    r"|\b\d+\s+(?:eggs?|lemons?|onions?|scallions?|sprigs?|cloves?|pinch)\b",
    re.I,
)
SENTENCE_SPLIT = re.compile(r"(?<=[.!?])\s+(?=[A-Z\"'])")


def normalize_mouzawak_text(text: str) -> str:
    text = re.sub(r"\r\n?", "\n", text or "")
    text = text.replace("\t", " ")
    text = re.sub(r"(\d+)\s*/\s*(\d+)", r"\1/\2", text)
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def looks_like_yield_cookbook(text: str) -> bool:
    clean = normalize_mouzawak_text(text)
    yield_count = len(YIELD_MARKER.findall(clean))
    serves_count = len(re.findall(r"Serves\s+\d+\s*\n\s*Ingredients", clean, re.I))
    return yield_count >= 8 and yield_count > serves_count * 2


def _parse_yield_count(raw: str) -> int:
    match = re.search(r"\d+", raw or "")
    return max(1, int(match.group())) if match else 1


def _find_section(text: str, pos: int) -> str:
    head = text[:pos]
    sections = list(SECTION_HEADER.finditer(head))
    if not sections:
        return ""
    return sections[-1].group(0).strip().title()


def _merge_ingredient_lines(raw: str) -> list[str]:
    lines = [ln.strip() for ln in raw.splitlines() if ln.strip()]
    merged: list[str] = []
    current = ""
    for line in lines:
        if ING_SECTION.match(line):
            if current:
                merged.append(current.strip())
                current = ""
            merged.append(line)
            continue
        if re.match(r"^(ingredients?|method)\b", line, re.I):
            continue
        candidate = f"{current} {line}".strip() if current else line
        if MEASURED.search(line) or line.endswith(")"):
            merged.append(candidate)
            current = ""
        else:
            current = candidate
    if current:
        merged.append(current.strip())
    return [ln for ln in merged if len(ln) > 2]


def _split_method_steps(raw: str) -> list[str]:
    raw = re.sub(r"\s+", " ", raw.strip())
    if not raw:
        return []
    parts = SENTENCE_SPLIT.split(raw)
    steps = [p.strip() for p in parts if len(p.strip()) > 12]
    if len(steps) < 2 and raw:
        return [raw]
    return steps


def _find_recipe_starts(text: str) -> list[re.Match[str]]:
    return list(TITLE_ARABIC.finditer(text))


def parse_yield_recipe_block(block: str, *, title: str, native: str, section: str) -> dict[str, Any] | None:
    block = normalize_mouzawak_text(block)
    match = YIELD_MARKER.search(block)
    if not match:
        return None

    before_yield = block[: match.start()].strip()
    after_yield = block[match.end() :].strip()
    intro = before_yield
    if intro.lower().startswith(title.lower()):
        intro = intro[len(title) :].strip()
    intro = re.sub(r"^\([^)]+\)\s*", "", intro).strip()

    ing_part = after_yield
    method_part = ""
    split_at = None
    for marker in (
        r"\bTo prepare\b",
        r"\bTo make\b",
        r"\bTo cook\b",
        r"\bHeat\b",
        r"\bCombine\b",
        r"\bMix\b",
        r"\bServe\b",
    ):
        hit = re.search(marker, ing_part, re.I)
        if hit and (split_at is None or hit.start() < split_at):
            split_at = hit.start()
    if split_at is not None and split_at > 20:
        method_part = ing_part[split_at:].strip()
        ing_part = ing_part[:split_at].strip()

    ingredients = _merge_ingredient_lines(ing_part)
    method = _split_method_steps(method_part)
    if len(ingredients) < 2 or len(method) < 2:
        return None

    serves = _parse_yield_count(match.group(1))
    display_title = re.sub(r"\s+", " ", title).strip().title()
    body_lines = [display_title, ""]
    if native:
        body_lines.extend([f"({native.strip()})", ""])
    if intro:
        body_lines.extend([intro, ""])
    body_lines.extend(["", f"Yield: {serves} servings", "", "Ingredients", *ingredients, "", "Method", *method])

    return {
        "title": display_title,
        "body": "\n".join(body_lines),
        "section": section,
        "serves": serves,
        "introduction": intro,
    }


def extract_yield_cookbook_pdf_chunks(path: Path) -> list[dict[str, str]] | None:
    """Return recipe chunks when PDF uses Yield: N servings layout."""
    pages = read_pdf_pages(path)
    full_text = normalize_mouzawak_text("\n\n".join(pages))
    if not looks_like_yield_cookbook(full_text):
        return None

    starts = _find_recipe_starts(full_text)
    if len(starts) < 5:
        return None

    chunks: list[dict[str, str]] = []
    for idx, start in enumerate(starts):
        title = start.group("title").strip()
        native = start.group("native").strip()
        block_start = start.start() + (2 if full_text[start.start() : start.start() + 2] == "\n\n" else 0)
        block_end = starts[idx + 1].start() if idx + 1 < len(starts) else len(full_text)
        block = full_text[block_start:block_end]
        section = _find_section(full_text, block_start)
        parsed = parse_yield_recipe_block(block, title=title, native=native, section=section)
        if not parsed:
            continue
        chunks.append(
            {
                "title": parsed["title"],
                "body": parsed["body"],
                "section": parsed.get("section") or "",
            }
        )

    return chunks or None
