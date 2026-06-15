"""Deterministic TCJ title and text cleanup — no LLM required."""

from __future__ import annotations

import re

LIGATURES = str.maketrans({"ﬁ": "fi", "ﬂ": "fl", "ﬀ": "ff", "ﬃ": "ffi", "ﬄ": "ffl"})

BROKEN_WORDS = (
    (re.compile(r"\bsaff\s+ron\b", re.I), "saffron"),
    (re.compile(r"\bstuff\s+ed\b", re.I), "stuffed"),
    (re.compile(r"\bshell\s+fi\s+sh\b", re.I), "shellfish"),
    (re.compile(r"\beggand\b", re.I), "egg and"),
    (re.compile(r"\bwithprawns\b", re.I), "with prawns"),
)

PAGE_JUNK = re.compile(
    r"^(?:poul\s*try|meat|seafood|vegetarian|desserts)\s*\d+\s*",
    re.I,
)
INSTRUCTION_TAIL = re.compile(
    r"(\([^)]+\))\s*(?:chilled|add\s+\d|whipping|until\s+thick|tbsp|tsp).*$",
    re.I,
)
SMALL_WORDS = frozenset({"a", "an", "the", "and", "or", "with", "in", "on", "of", "for", "to"})


def fix_ligatures(text: str) -> str:
    text = (text or "").translate(LIGATURES)
    for pattern, replacement in BROKEN_WORDS:
        text = pattern.sub(replacement, text)
    return re.sub(r"\s+", " ", text).strip()


def title_case(text: str) -> str:
    words = text.split()
    out: list[str] = []
    for i, w in enumerate(words):
        lw = w.lower()
        if i > 0 and lw in SMALL_WORDS:
            out.append(lw)
        elif lw:
            out.append(lw[0].upper() + lw[1:])
        else:
            out.append(w)
    return " ".join(out)


def clean_recipe_title(raw: str) -> str:
    """Turn messy extract titles into publishable names."""
    title = fix_ligatures(raw)
    title = PAGE_JUNK.sub("", title).strip()
    title = INSTRUCTION_TAIL.sub(r"\1", title).strip(" ,")

    if len(title) > 90 or re.search(r"\b(?:tbsp|tsp|ml|oz|whipping|chilled)\b", title, re.I):
        m = re.match(r"^([^(]{1,70}(?:\([^)]{0,30}\))?).*", title, re.I)
        if m:
            title = m.group(1).strip(" ,")
        if len(title) > 90:
            title = title[:87].rsplit(" ", 1)[0]

    if not title:
        return "Untitled Recipe"

    if "(" in title:
        main, _, paren = title.partition("(")
        main = title_case(main.strip())
        paren = title_case(paren.rstrip(")").strip())
        return f"{main} ({paren})" if paren else main

    return title_case(title)


def normalize_recipe_name_in_structured(structured: dict) -> dict:
    name = structured.get("recipe_name")
    if name:
        structured["recipe_name"] = clean_recipe_title(str(name))
    intro = structured.get("introduction")
    if intro and str(intro).strip() == "Imported from Personal book collection.":
        structured["introduction"] = ""
    return structured
