"""Climate-first copy — strip inbox city labels (Brisbane/Kerala) from public-facing text."""
from __future__ import annotations

import re

_CITY_COPY_REPLACEMENTS = (
    (re.compile(r"Brisbane's humid subtropical", re.I), "Humid subtropical"),
    (re.compile(r"Brisbane's", re.I), "Humid subtropical"),
    (re.compile(r"under Brisbane conditions", re.I), "in humid subtropical conditions"),
    (re.compile(r"\bin Brisbane\b", re.I), "in humid subtropical climates"),
    (re.compile(r"Brisbane summers", re.I), "humid subtropical summers"),
    (re.compile(r"Brisbane conditions", re.I), "humid subtropical conditions"),
    (re.compile(r"Brisbane:", re.I), "Humid subtropical:"),
    (re.compile(r"\bBrisbane\b", re.I), "humid subtropical climates"),
    (re.compile(r"Kerala's", re.I), "Tropical monsoon"),
    (re.compile(r"\bKerala\b", re.I), "tropical monsoon climates"),
    (re.compile(r"Thiruvalla's", re.I), "Tropical monsoon"),
    (re.compile(r"\bThiruvalla\b", re.I), "tropical monsoon climates"),
)

_VARIETY_TEXT_KEYS = (
    "origin", "traits", "flesh_fruit", "yield_notes", "growing_notes", "availability", "notes",
)


def neutralize_city_copy(text: str) -> str:
    if not text:
        return text
    out = text
    for pattern, repl in _CITY_COPY_REPLACEMENTS:
        out = pattern.sub(repl, out)
    return out


def neutralize_variety_record(rec: dict) -> dict:
    out = dict(rec)
    for key in _VARIETY_TEXT_KEYS:
        if key in out and isinstance(out[key], str):
            out[key] = neutralize_city_copy(out[key])
    return out


def neutralize_import_payload(data: dict) -> dict:
    varieties = [neutralize_variety_record(v) for v in data.get("varieties", [])]
    out = dict(data)
    out["varieties"] = varieties
    return out
