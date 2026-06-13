"""Shared parser for Variety Assessment docx / extracted text → structured cultivar payloads."""
from __future__ import annotations

import re
from pathlib import Path

CLIMATE_SECTIONS = {
    "BRISBANE": "humid-subtropical",
    "KERALA": "tropical-monsoon",
}

VARIETY_TITLE_RE = re.compile(
    r"^[A-Z0-9][^\n]{1,70}?(?:\s+[🏆🌱🧬🌏]+)+\s*$"
)
PAREN_LINEAGE_RE = re.compile(
    r"\((HEIRLOOM|OPEN[- ]?POLLINATED|HYBRID|INDIGENOUS|F1)\)",
    re.I,
)
FIELD_STARTS = (
    "origin:", "traits:", "flesh", "yield:", "notes:", "availability:",
    "requirements:", "type:", "maturity:", "adaptation:",
    "root:", "quality:", "disease resistance:", "climate required:",
    "commercial use:", "processing:", "purpose:", "issue:",
    "distinguishing feature:", "breeding focus:", "flowering:", "ginsenosides:",
)


def slugify(name: str) -> str:
    s = name.lower().strip()
    s = re.sub(r"[^a-z0-9]+", "-", s)
    return re.sub(r"-+", "-", s).strip("-")


def esc_sql(s: str) -> str:
    return (s or "").replace("'", "''")


def lineage_from_title(title: str) -> str:
    m = PAREN_LINEAGE_RE.search(title)
    if m:
        tag = m.group(1).upper().replace("-", " ").replace("  ", " ")
        if "HEIRLOOM" in tag:
            return "heirloom"
        if "HYBRID" in tag or tag.strip() == "F1":
            return "hybrid"
        if "INDIGENOUS" in tag:
            return "indigenous"
        return "open_pollinated"
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


def clean_variety_name(title: str) -> str:
    name = re.sub(r"\s*[🏆🌱🧬🌏]+\s*$", "", title).strip()
    name = re.sub(r"\s*\((?:HEIRLOOM|OPEN[- ]?POLLINATED|HYBRID|INDIGENOUS|F1)\)\s*$", "", name, flags=re.I)
    return name.strip()


def species_slug_from_name(species: str) -> str:
    return slugify(species.replace(" Assessment", ""))


def is_climate_noise(line: str) -> bool:
    upper = line.upper()
    if upper.startswith("ADDITIONAL "):
        return True
    if "VARIETIES SUITABLE" in upper or "VARIETY SUITABLE" in upper:
        return True
    if re.match(r"^\d+\+?\s", line):
        return True
    return False


def is_field_line(line: str) -> bool:
    low = line.lower()
    return any(low.startswith(k) for k in FIELD_STARTS)


def detect_climate_section(line: str) -> str | None:
    upper = line.upper()
    if "BRISBANE" in upper and ("VARIETIES" in upper or "VARIETY" in upper):
        return CLIMATE_SECTIONS["BRISBANE"]
    if "KERALA" in upper and ("VARIETIES" in upper or "VARIETY" in upper):
        return CLIMATE_SECTIONS["KERALA"]
    # Reference cultivar blocks without Brisbane/Kerala header (e.g. Ginseng Panax sections)
    if "CULTIVARS" in upper and "SUMMARY" not in upper:
        return CLIMATE_SECTIONS["BRISBANE"]
    return None


def is_variety_title(line: str, next_line: str | None = None) -> bool:
    if not line or len(line) < 2:
        return False
    if is_field_line(line):
        return False
    if is_climate_noise(line):
        return False
    if line.startswith("Brisbane Summary") or line.startswith("Kerala Summary"):
        return False
    if "VARIETIES" in line.upper() and "(" in line:
        return False
    if VARIETY_TITLE_RE.match(line):
        return True
    if PAREN_LINEAGE_RE.search(line):
        return True
    if re.match(
        r"^(HEIRLOOM|OPEN[- ]?POLLINATED|HYBRID|INDIGENOUS|F1)"
        r"(\s*/\s*(HEIRLOOM|OPEN[- ]?POLLINATED|HYBRID|INDIGENOUS|F1))*$",
        line,
        re.I,
    ):
        return False
    if next_line and is_field_line(next_line) and ":" not in line:
        if len(line) <= 80 and not line.endswith("."):
            return True
    return False


def parse_fields(lines: list[str]) -> dict[str, str]:
    fields: dict[str, str] = {}
    notes_parts: list[str] = []
    for line in lines:
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        key = k.strip().lower()
        val = v.strip()
        if key.startswith("notes"):
            notes_parts.append(val)
        else:
            fields[key] = val
    if notes_parts:
        fields["notes"] = " ".join(notes_parts)
    return fields


def variety_from_fields(block_title: str, fields: dict[str, str]) -> dict[str, str]:
    notes_key = next((k for k in fields if k.startswith("notes")), "notes")
    traits = fields.get("traits", fields.get("root", ""))
    type_val = fields.get("type", "")
    if type_val and traits:
        traits = type_val + "; " + traits
    elif type_val:
        traits = type_val
    extra_notes = []
    for key in (
        "quality", "disease resistance", "climate required", "commercial use",
        "processing", "purpose", "issue", "distinguishing feature", "breeding focus",
        "flowering", "ginsenosides",
    ):
        if fields.get(key):
            extra_notes.append(fields[key])
    growing = fields.get(notes_key, fields.get("adaptation", fields.get("notes", "")))
    if extra_notes:
        growing = (growing + " " + " ".join(extra_notes)).strip()
    yield_notes = fields.get("yield", fields.get("maturity", ""))
    return {
        "origin": fields.get("origin", ""),
        "traits": traits,
        "flesh_fruit": fields.get("flesh/fruit", fields.get("flesh", "")),
        "yield_notes": yield_notes,
        "growing_notes": growing,
        "availability": fields.get("availability", ""),
    }


def parse_assessment_text(text: str, species: str = "") -> dict:
    """Parse full assessment text into species + variety records with all inbox fields."""
    raw_lines = [raw.strip() for raw in text.splitlines() if raw.strip()]
    varieties: list[dict] = []
    current_climate: str | None = None
    block_title: str | None = None
    block_lines: list[str] = []
    order_by_climate: dict[str, int] = {}

    def flush_block() -> None:
        nonlocal block_title, block_lines
        if not block_title or not current_climate:
            block_title = None
            block_lines = []
            return
        name = clean_variety_name(block_title)
        if not name or len(name) < 2:
            block_title = None
            block_lines = []
            return
        fields = parse_fields(block_lines)
        parsed = variety_from_fields(block_title, fields)
        idx = order_by_climate.get(current_climate, 0)
        varieties.append({
            "name": name,
            "slug": slugify(name),
            "lineage_type": lineage_from_title(block_title),
            "climate_slug": current_climate,
            "sort_order": idx,
            **parsed,
        })
        order_by_climate[current_climate] = idx + 1
        block_title = None
        block_lines = []

    for i, line in enumerate(raw_lines):
        climate = detect_climate_section(line)
        if climate:
            flush_block()
            current_climate = climate
            continue
        if line.startswith("Brisbane Summary") or line.startswith("Kerala Summary"):
            flush_block()
            current_climate = None
            continue
        if line.startswith("📊") or line.startswith("✅ FINAL") or line.upper().startswith("END OF ASSESSMENT"):
            flush_block()
            current_climate = None
            continue
        if not current_climate:
            continue
        next_line = raw_lines[i + 1] if i + 1 < len(raw_lines) else None
        if is_variety_title(line, next_line):
            flush_block()
            block_title = line
            block_lines = []
            continue
        if block_title:
            block_lines.append(line)

    flush_block()

    sp = species or "Unknown"
    return {
        "species": sp,
        "species_slug": species_slug_from_name(sp),
        "varieties": varieties,
        "variety_count": len(varieties),
    }


def extract_species_meta(text: str, species: str = "") -> dict:
    """Lightweight header parse for kitchen profile SQL (family, requirements, summary)."""
    meta = {
        "species": species,
        "species_slug": species_slug_from_name(species),
        "botanical_name": "",
        "plant_family": "",
        "requirements": "",
        "care_summary": "",
        "gmo_note": "",
    }
    in_brisbane = False
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        low = line.lower()
        if line.startswith("Plants:") or line.startswith("Plant:"):
            meta["species"] = line.split(":", 1)[1].strip() or species
            meta["species_slug"] = species_slug_from_name(meta["species"])
        if low.startswith("family:"):
            meta["plant_family"] = line.split(":", 1)[1].strip()
        if "(" in line and ")" in line and not meta["botanical_name"]:
            m = re.search(r"\(([A-Z][a-z]+(?:\s+[a-z]+)+)\)", line)
            if m and len(m.group(1).split()) >= 2:
                meta["botanical_name"] = m.group(1)
        if detect_climate_section(line):
            in_brisbane = "BRISBANE" in line.upper()
        if in_brisbane and low.startswith("requirements:"):
            meta["requirements"] = line.split(":", 1)[1].strip()
        if line.startswith("Brisbane Summary"):
            meta["care_summary"] = line.split(":", 1)[-1].strip() if ":" in line else ""
        if "non-gmo" in low or "gmo status" in low:
            meta["gmo_note"] = line
    if not meta["care_summary"] and meta["requirements"]:
        meta["care_summary"] = meta["requirements"]
    if not meta["care_summary"]:
        meta["care_summary"] = f"Curated {meta['species']} profile — see cultivar notes for Brisbane and Kerala picks."
    return meta


def read_docx(path: Path) -> str:
    try:
        import docx
    except ImportError as exc:
        raise RuntimeError("pip install python-docx") from exc
    doc = docx.Document(str(path))
    return "\n".join(p.text for p in doc.paragraphs if p.text.strip())


def read_assessment_source(path: Path) -> tuple[str, str]:
    """Return (text, species_name)."""
    if path.suffix.lower() == ".docx":
        text = read_docx(path)
        m = re.search(r"Variety Assessment_(.+)\.docx$", path.name, re.I)
        species = m.group(1).strip() if m else path.stem
        return text, species
    text = path.read_text(encoding="utf-8", errors="replace")
    species = "Tomato" if "tomato" in path.name.lower() else path.stem
    return text, species


def dedupe_varieties(varieties: list[dict]) -> list[dict]:
    seen: set[tuple[str, str]] = set()
    out: list[dict] = []
    for v in varieties:
        key = (v["slug"], v["climate_slug"])
        if key in seen:
            continue
        seen.add(key)
        out.append(v)
    return out


def sql_variety_block(
    plant_slug: str,
    v: dict,
    *,
    link_ingredient: bool = True,
    ingredient_like: str | None = None,
) -> list[str]:
    """Generate PL/pgSQL lines for one cultivar (uses v_plant, v_climate, v_var, v_ing)."""
    ing_like = ingredient_like or plant_slug
    lines = [
        f"  -- {v['name']} ({v['climate_slug']})",
        (
            "  INSERT INTO public.plant_varieties (plant_id, slug, name, lineage_type, origin, traits, flesh_fruit, yield_notes, growing_notes, availability, sort_order, is_published)"
            f"\n  SELECT v_plant, '{esc_sql(v['slug'])}', '{esc_sql(v['name'])}', '{v['lineage_type']}',"
            f" '{esc_sql(v['origin'])}', '{esc_sql(v['traits'])}', '{esc_sql(v['flesh_fruit'])}',"
            f" '{esc_sql(v['yield_notes'])}', '{esc_sql(v['growing_notes'])}', '{esc_sql(v['availability'])}', {v['sort_order']}, true"
            f"\n  WHERE NOT EXISTS (SELECT 1 FROM public.plant_varieties WHERE plant_id = v_plant AND slug = '{esc_sql(v['slug'])}');"
        ),
        f"  SELECT id INTO v_var FROM public.plant_varieties WHERE plant_id = v_plant AND slug = '{esc_sql(v['slug'])}' LIMIT 1;",
        f"  SELECT id INTO v_climate FROM public.climate_zones WHERE slug = '{v['climate_slug']}' LIMIT 1;",
        "  IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN",
        (
            "    INSERT INTO public.variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)"
            f"\n    VALUES (v_var, v_climate, 'recommended', '{esc_sql(v['growing_notes'][:500])}')"
            "\n    ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;"
        ),
    ]
    if link_ingredient:
        lines += [
            "    IF v_ing IS NOT NULL THEN",
            (
                "      INSERT INTO public.variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)"
                f"\n      VALUES (v_var, v_ing, 'fruit', true, 'Variety: {esc_sql(v['name'])}')"
                "\n      ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;"
            ),
            "    END IF;",
        ]
    lines += ["  END IF;", ""]
    return lines


def sql_seed_header(plant_slug: str, ingredient_like: str | None = None) -> list[str]:
    ing_like = ingredient_like or plant_slug
    return [
        "DO $$",
        "DECLARE",
        "  v_plant uuid;",
        "  v_climate uuid;",
        "  v_var uuid;",
        "  v_ing integer;",
        "BEGIN",
        f"  SELECT id INTO v_plant FROM public.plants WHERE slug = '{esc_sql(plant_slug)}' LIMIT 1;",
        f"  IF v_plant IS NULL THEN RAISE EXCEPTION 'plant {esc_sql(plant_slug)} missing — seed species first'; END IF;",
        f"  SELECT \"ID\" INTO v_ing FROM public.ingredients WHERE lower(\"Ingredient Name\") LIKE '%{esc_sql(ing_like)}%' ORDER BY \"ID\" LIMIT 1;",
        "",
    ]


def sql_seed_footer(count: int, source_path: str, species_name: str, species_slug: str) -> list[str]:
    return [
        "END $$;",
        "",
        "INSERT INTO public.garden_import_queue (source_path, species_name, species_slug, climate_slug, status, variety_count, payload, processed_at)",
        f"VALUES ('{esc_sql(source_path)}', '{esc_sql(species_name)}', '{esc_sql(species_slug)}', 'multi', 'approved', {count},",
        f" '{{\"generated\": true, \"variety_count\": {count}}}'::jsonb, now())",
        "ON CONFLICT DO NOTHING;",
        "",
        f"SELECT 'ready — {count} varieties for {esc_sql(species_slug)}' AS status;",
    ]
