#!/usr/bin/env python3
"""Generate garden-v4-07-seed-tomato-varieties.sql from brainstorm-inbox/_extracted_tomato.txt"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "brainstorm-inbox" / "_extracted_tomato.txt"
OUT = ROOT / "database" / "sql" / "garden-v4-07-seed-tomato-varieties.sql"

EMOJI_LINEAGE = {
    "🏆": "heirloom",
    "🌱": "open_pollinated",
    "🧬": "hybrid",
    "🌏": "indigenous",
}

CLIMATE_MAP = {
    "BRISBANE": "humid-subtropical",
    "KERALA": "tropical-monsoon",
}


def slugify(name: str) -> str:
    s = name.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return s.strip("-")


def esc(s: str) -> str:
    return (s or "").replace("'", "''")


def lineage_from_title(title: str) -> str:
    if "🌏" in title and "🌱" in title:
        return "indigenous"
    if "🏆" in title:
        return "heirloom"
    if "🧬" in title:
        return "hybrid"
    if "🌱" in title:
        return "open_pollinated"
    if "🌏" in title:
        return "indigenous"
    return "open_pollinated"


def parse_varieties(text: str, section_key: str) -> list[dict]:
    climate = CLIMATE_MAP[section_key]
    marker = "BRISBANE VARIETIES" if section_key == "BRISBANE" else "KERALA"
    start = text.find(marker)
    if start < 0:
        return []
    end = text.find("Brisbane Summary:") if section_key == "BRISBANE" else len(text)
    if section_key == "BRISBANE":
        end = text.find("KERALA", start)
    chunk = text[start:end]

    varieties = []
    blocks = re.split(r"\n(?=[A-Z][^\n]{2,60}(?: 🏆| 🌱| 🧬| 🌏))", chunk)
    order = 0
    for block in blocks:
        lines = [l.strip() for l in block.strip().splitlines() if l.strip()]
        if not lines:
            continue
        title = lines[0]
        if "VARIETIES" in title or title.startswith("Requirements:"):
            continue
        name = re.sub(r"\s*[🏆🌱🧬🌏]+\s*$", "", title).strip()
        if not name or len(name) < 2:
            continue
        fields = {}
        for line in lines[1:]:
            if ":" in line:
                k, v = line.split(":", 1)
                fields[k.strip().lower()] = v.strip()
        notes_key = None
        for k in fields:
            if k.startswith("notes"):
                notes_key = k
                break
        varieties.append({
            "slug": slugify(name),
            "name": name,
            "lineage": lineage_from_title(title),
            "climate": climate,
            "origin": fields.get("origin", ""),
            "traits": fields.get("traits", ""),
            "flesh_fruit": fields.get("flesh/fruit", fields.get("flesh", "")),
            "yield_notes": fields.get("yield", ""),
            "growing_notes": fields.get(notes_key or "notes", ""),
            "availability": fields.get("availability", ""),
            "sort_order": order,
        })
        order += 1
    return varieties


def main():
    text = SRC.read_text(encoding="utf-8", errors="replace")
    all_v = parse_varieties(text, "BRISBANE") + parse_varieties(text, "KERALA")
    # dedupe by slug+climate
    seen = set()
    unique = []
    for v in all_v:
        key = (v["slug"], v["climate"])
        if key in seen:
            continue
        seen.add(key)
        unique.append(v)

    lines = [
        "-- garden-v4-07-seed-tomato-varieties.sql — auto-generated from _extracted_tomato.txt",
        "-- Safe to re-run. Publishes cultivars for humid-subtropical + tropical-monsoon.",
        "",
        "DO $$",
        "DECLARE",
        "  v_plant uuid;",
        "  v_climate uuid;",
        "  v_var uuid;",
        "  v_ing integer;",
        "BEGIN",
        "  SELECT id INTO v_plant FROM public.plants WHERE slug = 'tomato' LIMIT 1;",
        "  IF v_plant IS NULL THEN RAISE EXCEPTION 'tomato plant missing — run RUN-GARDEN-V3.sql first'; END IF;",
        "  SELECT \"ID\" INTO v_ing FROM public.ingredients WHERE lower(\"Ingredient Name\") LIKE '%tomato%' ORDER BY \"ID\" LIMIT 1;",
        "",
    ]

    for v in unique:
        lines.append(f"  -- {v['name']} ({v['climate']})")
        lines.append(
            f"  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)"
            f"\n  SELECT v_plant, '{esc(v['slug'])}', '{esc(v['name'])}', '{v['lineage']}',"
            f" '{esc(v['origin'])}', '{esc(v['traits'])}', '{esc(v['flesh_fruit'])}',"
            f" '{esc(v['yield_notes'])}', '{esc(v['growing_notes'])}', '{esc(v['availability'])}', {v['sort_order']}, true"
            f"\n  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = '{esc(v['slug'])}');"
        )
        lines.append(
            f"  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = '{esc(v['slug'])}' LIMIT 1;"
        )
        lines.append(
            f"  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = '{v['climate']}' LIMIT 1;"
        )
        lines.append(
            "  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN"
            f"\n    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)"
            f"\n    VALUES (v_var, v_climate, 'recommended', '{esc(v['growing_notes'][:500])}')"
            f"\n    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;"
        )
        lines.append(
            "    IF v_ing IS NOT NULL THEN"
            f"\n      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)"
            f"\n      VALUES (v_var, v_ing, 'fruit', true, 'Variety: {esc(v['name'])}')"
            f"\n      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;"
            "\n    END IF;"
            "\n  END IF;"
            ""
        )

    lines += [
        "END $$;",
        "",
        "INSERT INTO public.garden_import_queue (source_path, species_name, species_slug, climate_slug, status, variety_count, payload)",
        f"VALUES ('brainstorm-inbox/_extracted_tomato.txt', 'Tomato', 'tomato', 'multi', 'approved', {len(unique)},",
        f" '{{\"generated\": true, \"variety_count\": {len(unique)}}}'::jsonb)",
        "ON CONFLICT DO NOTHING;",
        "",
        f"SELECT 'garden-v4-07-seed-tomato-varieties ready — {len(unique)} varieties' AS status;",
    ]

    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {len(unique)} varieties to {OUT}")


if __name__ == "__main__":
    main()
