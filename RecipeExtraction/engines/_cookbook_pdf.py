"""Cookbook PDF parsing — Serves / Ingredients / Method layout (Marshall Cavendish etc.)."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

INDD_FOOTER = re.compile(r"Rice\d+[^\n]*\.indd[^\n]*", re.I)
DATE_STAMP = re.compile(r"\b\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2}:\d{2}\b")
SECTION_LINE = re.compile(
    r"^(?:\d+\s+)?(?:VEGETARIAN|SEAFOOD|POULTRY|MEAT|DESSERTS)\s*(?:\d+\s*)?$",
    re.I,
)
SERVES_INGREDIENTS = re.compile(
    r"Serves\s+(?P<serves>\d+(?:\s*[-–—?]\s*\d+)?)\s*\n?\s*Ingredients\s*\n(?P<ingredients>.*?)\n\s*Method\s*\n(?P<method>.*)",
    re.S | re.I,
)
GLOSSARY_ENTRY = re.compile(r"^\d+\.\s+[A-Za-z].{0,80}$", re.M)
MEASURED = re.compile(
    r"\d+\s*(?:g|kg|oz|ml|l|litre|liter|cup|cups|tbsp|tsp|pint|pints)\b|\b\d+\s+(?:eggs?|lemons?)\b",
    re.I,
)


def read_pdf_pages(path: Path) -> list[str]:
    from pypdf import PdfReader

    reader = PdfReader(str(path))
    return [(page.extract_text() or "") for page in reader.pages]


def clean_pdf_text(text: str) -> str:
    text = re.sub(r"\r\n?", "\n", text or "")
    text = text.translate(str.maketrans({"ﬁ": "fi", "ﬂ": "fl", "ﬀ": "ff", "ﬃ": "ffi", "ﬄ": "ffl"}))
    text = INDD_FOOTER.sub("", text)
    text = DATE_STAMP.sub("", text)
    text = re.sub(r"\n•\s*(?=\n|$)", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def page_is_glossary(text: str) -> bool:
    clean = clean_pdf_text(text)
    if re.search(r"^\s*glossary\s*$", clean, re.I | re.M):
        return True
    if GLOSSARY_ENTRY.search(clean) and not re.search(r"Serves\s+\d+", clean, re.I):
        return len(GLOSSARY_ENTRY.findall(clean)) >= 3
    return False


def page_has_recipe_core(text: str) -> bool:
    return bool(re.search(r"Serves\s+\d+", text, re.I) and re.search(r"\bIngredients\b", text, re.I))


def looks_like_serves_cookbook(text: str) -> bool:
    return len(re.findall(r"Serves\s+\d+", text, re.I)) >= 3


def recipe_region_complete(text: str) -> bool:
    return bool(
        re.search(r"Serves\s+\d+", text, re.I)
        and re.search(r"\bIngredients\b", text, re.I)
        and re.search(r"\bMethod\b", text, re.I)
    )


def merge_recipe_pages(pages: list[str]) -> list[str]:
    buffers: list[str] = []
    current = ""
    for page in pages:
        if page_is_glossary(page):
            break
        clean = clean_pdf_text(page)
        if not clean:
            continue
        has_serves = bool(re.search(r"Serves\s+\d+", clean, re.I))
        has_ing = bool(re.search(r"\bIngredients\b", clean, re.I))

        if has_serves and has_ing:
            if current and recipe_region_complete(current):
                buffers.append(current)
                current = clean
            elif current and not recipe_region_complete(current):
                current = f"{current}\n\n{clean}"
            else:
                current = clean
            if recipe_region_complete(current):
                buffers.append(current)
                current = ""
        elif current:
            current = f"{current}\n\n{clean}"
            if recipe_region_complete(current):
                buffers.append(current)
                current = ""

    if current.strip() and recipe_region_complete(current):
        buffers.append(current.strip())
    return buffers


def _parse_title_and_intro(head: str) -> tuple[str, str, str]:
    lines = [ln.strip() for ln in head.splitlines() if ln.strip() and ln.strip() != "•"]
    lines = [ln for ln in lines if not SECTION_LINE.match(ln)]

    section = ""
    for ln in head.splitlines():
        hit = re.match(r"^(?:\d+\s+)?(VEGETARIAN|SEAFOOD|POULTRY|MEAT|DESSERTS)\b", ln.strip(), re.I)
        if hit:
            section = hit.group(1).title()
            break
        hit = re.match(r"^(VEGETARIAN|SEAFOOD|POULTRY|MEAT|DESSERTS)\s+\d+\s*$", ln.strip(), re.I)
        if hit:
            section = hit.group(1).title()
            break

    title_lines: list[str] = []
    intro_lines: list[str] = []
    for line in lines:
        if line.startswith("("):
            title_lines.append(line)
            continue
        if not intro_lines and len(line) < 55 and not line.endswith("."):
            title_lines.append(line)
            continue
        intro_lines.append(line)

    title = re.sub(r"\s+", " ", " ".join(title_lines)).strip(" ,")
    intro = re.sub(r"\s+", " ", " ".join(intro_lines)).strip()
    return title, intro, section


def _merge_wrapped_ingredient_lines(raw: str) -> list[str]:
    lines = [ln.strip() for ln in raw.splitlines() if ln.strip() and ln.strip() != "•"]
    merged: list[str] = []
    current = ""
    for line in lines:
        if re.match(r"^(ingredients?|garnishing|method)\b", line, re.I):
            if current:
                merged.append(current.strip())
                current = ""
            if line.lower() != "garnishing":
                merged.append(line)
            else:
                merged.append("Garnishing")
            continue
        candidate = f"{current} {line}".strip() if current else line
        if current and MEASURED.search(line):
            merged.append(candidate)
            current = ""
        elif current and MEASURED.search(current):
            merged.append(current)
            current = line
        elif MEASURED.search(line) or line.endswith(")"):
            merged.append(candidate)
            current = ""
        else:
            current = candidate
    if current:
        merged.append(current.strip())
    return [ln for ln in merged if ln.lower() not in {"ingredients", "method"}]


def _split_method_steps(raw: str) -> list[str]:
    raw = INDD_FOOTER.sub("", raw)
    lines = [ln.strip() for ln in raw.splitlines() if ln.strip() and ln.strip() != "•"]
    steps: list[str] = []
    current = ""
    for line in lines:
        if re.match(r"^(method|instructions?)\b", line, re.I):
            continue
        current = f"{current} {line}".strip() if current else line
        if re.search(r"[.!]\s*$", current):
            steps.append(current)
            current = ""
    if current:
        steps.append(current)
    return steps


def _parse_serves_count(raw: str) -> int:
    match = re.search(r"\d+", raw or "")
    return max(1, int(match.group())) if match else 1


def parse_serves_recipe_block(block: str) -> dict[str, Any] | None:
    match = SERVES_INGREDIENTS.search(block)
    if not match:
        return None

    head = block[: match.start()].strip()
    title, intro, section = _parse_title_and_intro(head)
    if not title or len(title) < 3:
        return None

    ingredients = _merge_wrapped_ingredient_lines(match.group("ingredients"))
    method = _split_method_steps(match.group("method"))
    if len(ingredients) < 2 or len(method) < 2:
        return None

    serves = _parse_serves_count(match.group("serves"))
    body_lines = [title, ""]
    if intro:
        body_lines.extend([intro, ""])
    body_lines.append(f"Serves {serves}")
    body_lines.extend(["", "Ingredients", *ingredients, "", "Method", *method])
    body = "\n".join(body_lines)

    return {
        "title": title,
        "body": body,
        "section": section,
        "serves": serves,
        "introduction": intro,
    }


def extract_cookbook_pdf_chunks(path: Path) -> list[dict[str, str]] | None:
    """Return recipe chunks when PDF uses Serves/Ingredients/Method layout."""
    pages = read_pdf_pages(path)
    recipe_pages: list[str] = []
    started = False
    for page in pages:
        if page_is_glossary(page):
            break
        if not started:
            if page_has_recipe_core(page) or re.search(r"\bMethod\b", page, re.I):
                started = True
            else:
                continue
        recipe_pages.append(page)

    if not recipe_pages:
        return None

    full_text = clean_pdf_text("\n\n".join(recipe_pages))
    if not looks_like_serves_cookbook(full_text):
        return None

    chunks: list[dict[str, str]] = []
    for block in merge_recipe_pages(recipe_pages):
        parsed = parse_serves_recipe_block(block)
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
