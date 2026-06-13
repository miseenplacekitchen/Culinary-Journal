#!/usr/bin/env python3
"""
Generate fix-phase54-garden-kitchen-profiles.sql — species profiles + care + calendar
for kitchen-priority plants (extracted from Variety Assessment docx headers).

Run after fix-phase54-import-payload-refresh.sql and re-apply imports in GM.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INBOX = ROOT / "brainstorm-inbox" / "Variety Assessments"
OUT = ROOT / "database" / "sql" / "fix-phase54-garden-kitchen-profiles.sql"

sys.path.insert(0, str(ROOT / "scripts"))
from garden_ingest_lib import esc_sql, extract_species_meta, read_assessment_source  # noqa: E402

KITCHEN_PRIORITY = [
    "bell-pepper", "basil", "cucumber", "spinach", "carrot", "potato", "pumpkin",
    "zucchini", "onion", "garlic", "coriander", "peas", "chili-pepper",
    "strawberry", "broccoli",
]

HERBS = {"basil", "coriander", "mint", "parsley", "thyme", "rosemary"}
ROOTS = {"carrot", "potato", "radish", "turnip", "beetroot", "sweet-potato"}
FRUITING = {
    "bell-pepper", "chili-pepper", "cucumber", "zucchini", "pumpkin", "tomato",
    "eggplant", "watermelon", "melon",
}


def docx_for_slug(slug: str) -> Path | None:
    needle = slug.replace("-", " ").lower()
    for p in INBOX.glob("Variety Assessment_*.docx"):
        if needle in p.stem.lower().replace("_", " "):
            return p
    return None


def calendar_rows(slug: str) -> list[tuple[str, int, int, str]]:
    if slug in HERBS:
        return [
            ("sow", 3, 11, "Succession sow in pots or direct; partial shade in hot months"),
            ("harvest", 1, 12, "Pick leaves regularly to encourage bushy growth"),
            ("prune", 10, 2, "Trim flower heads on leafy herbs to extend leaf harvest"),
        ]
    if slug in ROOTS:
        return [
            ("sow", 3, 5, "Direct sow or punnets; keep seed bed moist"),
            ("sow", 8, 9, "Autumn succession sowing for cooler harvest window"),
            ("harvest", 6, 11, "Harvest when size and colour indicate maturity"),
        ]
    if slug in FRUITING:
        return [
            ("sow", 8, 9, "Start indoors or buy seedlings before peak heat"),
            ("transplant", 10, 11, "Plant out after frost risk; stake or trellis as needed"),
            ("harvest", 12, 4, "Pick regularly to keep plants productive"),
        ]
    return [
        ("sow", 3, 9, "Follow seed packet timing for Brisbane subtropical windows"),
        ("harvest", 6, 12, "Harvest young and often for best quality"),
    ]


def care_rows(requirements: str) -> list[tuple[str, str, str, str]]:
    req = requirements or "Full sun, well-drained soil, consistent moisture."
    return [
        ("sunlight", "6+ hours direct sun (partial shade in peak summer for delicate crops)", "Leggy or scorched plants", "Adjust position or use shade cloth Dec–Feb"),
        ("water", "Even moisture; avoid wet foliage overnight", "Split fruit, fungal issues", "Mulch and water at soil level mornings"),
        ("soil", "Rich, well-drained compost; pH suited to crop", "Poor drainage or nutrient lock-out", "Raised beds or large pots with fresh mix"),
        ("frost", "Protect frost-tender crops in cool snaps", "Blackened or stalled growth", "Cover, move pots, or delay planting"),
        ("pest_mgmt", req[:200], "Aphids, caterpillars, snails after rain", "Inspect weekly; hand pick; hose blast early infestations"),
    ]


def species_block(slug: str, meta: dict) -> list[str]:
    name = meta.get("species") or slug.replace("-", " ").title()
    botanical = meta.get("botanical_name") or ""
    family = meta.get("plant_family") or ""
    care_summary = meta.get("care_summary") or f"Kitchen-garden {name} — Brisbane subtropical profile seeded from Variety Assessment."
    requirements = meta.get("requirements") or care_summary

    lines = [
        f"-- {name} ({slug})",
        "DO $$",
        "DECLARE v_plant uuid; v_cz uuid;",
        "BEGIN",
        f"  SELECT id INTO v_plant FROM public.plants WHERE slug = '{esc_sql(slug)}' LIMIT 1;",
        f"  IF v_plant IS NULL THEN RAISE NOTICE 'skip {esc_sql(slug)} — plant shell missing'; RETURN; END IF;",
        "  UPDATE public.plants SET",
        f"    botanical_name = COALESCE(NULLIF(btrim(botanical_name), ''), '{esc_sql(botanical)}'),",
        f"    plant_family = COALESCE(NULLIF(btrim(plant_family), ''), '{esc_sql(family)}'),",
        f"    care_summary = '{esc_sql(care_summary[:500])}',",
        f"    edible_parts = COALESCE(NULLIF(btrim(edible_parts), ''), 'Leaves, stems, roots, or fruit — see cultivar notes'),",
        f"    culinary_applications = COALESCE(NULLIF(btrim(culinary_applications), ''), 'Kitchen staple — link governed ingredient in GM when ready'),",
        "    updated_at = now()",
        "  WHERE id = v_plant;",
        "",
        "  SELECT id INTO v_cz FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1;",
        "  IF v_cz IS NOT NULL THEN",
    ]
    for field_key, core, risk, fix in care_rows(requirements):
        lines += [
            "    INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)",
            f"    VALUES (v_plant, v_cz, '{esc_sql(field_key)}', '{esc_sql(core)}', '{esc_sql(risk)}', '{esc_sql(fix)}')",
            "    ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET",
            "      core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;",
        ]
    for activity, m_start, m_end, notes in calendar_rows(slug):
        lines += [
            "    INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)",
            f"    SELECT v_plant, v_cz, '{esc_sql(activity)}', {m_start}, {m_end}, '{esc_sql(notes)}'",
            "    WHERE NOT EXISTS (",
            "      SELECT 1 FROM public.plant_calendar pc",
            f"      WHERE pc.plant_id = v_plant AND pc.activity = '{esc_sql(activity)}'",
            f"        AND pc.month_start = {m_start} AND pc.month_end = {m_end}",
            "    );",
        ]
    lines += [
        "  END IF;",
        "",
        "  INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)",
        "  SELECT v_plant, sub.ing_id, 'fruit', true",
        "  FROM (",
        f"    SELECT \"ID\" AS ing_id FROM public.ingredients",
        f"    WHERE lower(\"Ingredient Name\") LIKE '%{esc_sql(slug.replace('-', ' '))}%'",
        "    ORDER BY \"ID\" LIMIT 1",
        "  ) sub",
        "  WHERE sub.ing_id IS NOT NULL",
        "    AND NOT EXISTS (SELECT 1 FROM public.plant_ingredients pi WHERE pi.plant_id = v_plant AND pi.is_primary = true);",
        "END $$;",
        "",
    ]
    return lines


def main() -> None:
    lines = [
        "-- fix-phase54-garden-kitchen-profiles.sql",
        "-- Kitchen-priority species: care summary, humid-subtropical care fields, calendar, ingredient hinge.",
        "-- Safe to re-run. Does NOT auto-publish — publish each species in GM when curated.",
        "",
    ]
    done = 0
    for slug in KITCHEN_PRIORITY:
        p = docx_for_slug(slug)
        if not p:
            print(f"Skip {slug} — docx not found")
            continue
        text, species = read_assessment_source(p)
        meta = extract_species_meta(text, species)
        meta["species_slug"] = slug
        lines.extend(species_block(slug, meta))
        done += 1

    lines.append(f"SELECT 'fix-phase54-garden-kitchen-profiles ready — {done} species' AS status;")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT} ({done} species)")


if __name__ == "__main__":
    main()
