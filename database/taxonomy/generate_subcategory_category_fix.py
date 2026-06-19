#!/usr/bin/env python3
"""Generate fix-subcategory-categories.sql from book taxonomy sources."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "database" / "sql" / "fix-subcategory-categories.sql"

JS_FILES = [
    ("Garden & Earth", ROOT / "lib" / "tcj-garden-taxonomy.js"),
    ("Feather & Flock", ROOT / "lib" / "tcj-feather-flock-taxonomy.js"),
    ("Pasture & Hoof", ROOT / "lib" / "tcj-pasture-hoof-taxonomy.js"),
    ("Ocean & River", ROOT / "lib" / "tcj-ocean-river-taxonomy.js"),
    ("The Grain Field", ROOT / "lib" / "tcj-grain-field-taxonomy.js"),
    ("Sips & Stories", ROOT / "lib" / "tcj-sips-stories-taxonomy.js"),
]

SQL_SEED = ROOT / "database" / "sql" / "fix-book-taxonomy.sql"
GARDEN_SQL = ROOT / "database" / "sql" / "fix-garden-taxonomy.sql"
SIPS_SQL = ROOT / "database" / "sql" / "fix-sips-stories-taxonomy.sql"

INSERT_RE = re.compile(
    r"\(\s*'((?:''|[^'])*)'\s*,\s*'((?:''|[^'])*)'\s*,"
)


def unescape_sql(s: str) -> str:
    return s.replace("''", "'")


def names_from_js(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    return [m.group(1) for m in re.finditer(r"name:\s*'((?:\\'|[^'])*)'", text)]


def pairs_from_sql(path: Path) -> list[tuple[str, str]]:
    out: list[tuple[str, str]] = []
    if not path.exists():
        return out
    text = path.read_text(encoding="utf-8")
    for cat, name in INSERT_RE.findall(text):
        out.append((unescape_sql(cat), unescape_sql(name)))
    return out


def build_mapping() -> dict[str, str]:
    mapping: dict[str, str] = {}
    for category, js_path in JS_FILES:
        if not js_path.exists():
            continue
        for name in names_from_js(js_path):
            mapping[name] = category
    for cat, name in pairs_from_sql(SQL_SEED):
        mapping[name] = cat
    for cat, name in pairs_from_sql(GARDEN_SQL):
        mapping[name] = cat
    for cat, name in pairs_from_sql(SIPS_SQL):
        mapping[name] = cat
    return mapping


def sql_quote(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def main() -> None:
    mapping = build_mapping()
    rows = sorted(mapping.items(), key=lambda x: (x[1], x[0]))

    lines: list[str] = [
        "-- fix-subcategory-categories.sql",
        "-- Reassign recipe_subcategories.category (and divisions) by BOOK sub name.",
        "-- Fixes fix-categories-v2.sql bulk move of ALL 'Meat & Fire' rows → Feather & Flock.",
        "-- Run once in Supabase SQL Editor. Safe to re-run.",
        "",
        "-- ── 1. Before (audit) ─────────────────────────────────────────────────────",
        "SELECT name, category",
        "FROM public.recipe_subcategories",
        "WHERE is_active = true",
        "ORDER BY category, name;",
        "",
        "-- ── 2. Mapping table (" + str(len(rows)) + " book sub-categories) ─────────────",
        "CREATE TEMP TABLE IF NOT EXISTS tcj_sub_category_fix (",
        "  sub_name text PRIMARY KEY,",
        "  canon_category text NOT NULL",
        ") ON COMMIT DROP;",
        "TRUNCATE tcj_sub_category_fix;",
        "",
        "INSERT INTO tcj_sub_category_fix (sub_name, canon_category) VALUES",
    ]

    value_lines = [
        f"  ({sql_quote(name)}, {sql_quote(cat)})" for name, cat in rows
    ]
    lines.append(",\n".join(value_lines) + ";")

    lines.extend(
        [
            "",
            "-- ── 3. Deactivate duplicate wrong-category rows when correct row exists ──",
            "UPDATE public.recipe_subcategories wrong",
            "SET is_active = false",
            "FROM tcj_sub_category_fix m",
            "WHERE wrong.name = m.sub_name",
            "  AND wrong.is_active = true",
            "  AND wrong.category IS DISTINCT FROM m.canon_category",
            "  AND EXISTS (",
            "    SELECT 1 FROM public.recipe_subcategories right_row",
            "    WHERE right_row.name = m.sub_name",
            "      AND right_row.category = m.canon_category",
            "      AND right_row.is_active = true",
            "      AND right_row.id <> wrong.id",
            "  );",
            "",
            "-- ── 4. Move remaining misassigned subs to canonical category ───────────────",
            "UPDATE public.recipe_subcategories rs",
            "SET category = m.canon_category",
            "FROM tcj_sub_category_fix m",
            "WHERE rs.name = m.sub_name",
            "  AND rs.is_active = true",
            "  AND rs.category IS DISTINCT FROM m.canon_category;",
            "",
            "-- ── 5. Align recipe_divisions.category with sub name mapping ───────────────",
            "UPDATE public.recipe_divisions rd",
            "SET category = m.canon_category",
            "FROM tcj_sub_category_fix m",
            "WHERE rd.subcategory = m.sub_name",
            "  AND rd.is_active = true",
            "  AND rd.category IS DISTINCT FROM m.canon_category;",
            "",
            "-- ── 6. After (verify) ───────────────────────────────────────────────────────",
            "SELECT name, category",
            "FROM public.recipe_subcategories",
            "WHERE is_active = true",
            "ORDER BY category, name;",
            "",
            "-- Misassigned: active subs whose category does not match book mapping",
            "SELECT rs.name, rs.category AS current_category, m.canon_category AS should_be",
            "FROM public.recipe_subcategories rs",
            "LEFT JOIN tcj_sub_category_fix m ON m.sub_name = rs.name",
            "WHERE rs.is_active = true",
            "  AND (m.canon_category IS NULL OR rs.category IS DISTINCT FROM m.canon_category)",
            "ORDER BY rs.category, rs.name;",
            "",
            "SELECT category, COUNT(*) AS sub_count",
            "FROM public.recipe_subcategories",
            "WHERE is_active = true",
            "GROUP BY category",
            "ORDER BY category;",
        ]
    )

    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT} ({len(rows)} mappings)")


if __name__ == "__main__":
    main()
