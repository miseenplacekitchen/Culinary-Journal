#!/usr/bin/env python3
"""
Emit fix-phase54-import-payload-refresh.sql — attach updated JSON payloads for
species whose cultivar counts changed (parser v2 + mangosteen summary).

Run on Supabase, then GM Interface → Apply all pending imports (or per-species).
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "brainstorm-inbox" / "import-payloads"
OUT = ROOT / "database" / "sql" / "fix-phase54-import-payload-refresh.sql"

REFRESH_SLUGS = {
    "amaranth", "betel-leaf", "bilimbi", "carrot", "ginseng", "goldenrod",
    "mango", "mangosteen", "peas", "pomelo", "radish", "rye",
}

sys.path.insert(0, str(ROOT / "scripts"))
from garden_ingest_lib import esc_sql  # noqa: E402


def main() -> None:
    lines = [
        "-- fix-phase54-import-payload-refresh.sql",
        "-- Attach re-parsed cultivar payloads (parser v2). Safe to re-run.",
        "-- After run: Admin → GM Interface → Apply all pending imports.",
        "",
    ]
    count = 0
    for p in sorted(PAYLOADS.glob("*.json")):
        slug = p.stem
        if slug not in REFRESH_SLUGS:
            continue
        data = json.loads(p.read_text(encoding="utf-8"))
        source = f"brainstorm-inbox/import-payloads/{p.name}"
        payload_json = json.dumps(data, ensure_ascii=False).replace("'", "''")
        vc = data.get("variety_count", len(data.get("varieties", [])))
        lines += [
            f"-- {data.get('species', slug)} ({vc} cultivars)",
            "UPDATE public.garden_import_queue SET",
            f"  payload = '{payload_json}'::jsonb,",
            f"  variety_count = {vc},",
            "  status = CASE WHEN status = 'approved' THEN 'parsed' ELSE status END",
            f"WHERE species_slug = '{esc_sql(slug)}'",
            f"   OR source_path = '{esc_sql(source)}';",
            "",
        ]
        count += 1

    lines.append(f"SELECT 'fix-phase54-import-payload-refresh ready — {count} payloads' AS status;")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT} ({count} payloads)")


if __name__ == "__main__":
    main()
