#!/usr/bin/env python3
"""
Attach JSON payloads to garden_import_queue rows (for GM Apply).
Writes garden-v4-10b-import-payloads.sql in chunks (max species per file).
Run after scan-garden-inbox-queue.py. Paste each chunk in Supabase if file is large.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "brainstorm-inbox" / "import-payloads"
SQL_DIR = ROOT / "database" / "sql"
CHUNK = 25

sys.path.insert(0, str(ROOT / "scripts"))
from garden_ingest_lib import esc_sql  # noqa: E402


def main() -> None:
    files = sorted(PAYLOADS.glob("*.json"))
    if not files:
        print("No payloads found")
        sys.exit(1)

    chunks = [files[i : i + CHUNK] for i in range(0, len(files), CHUNK)]
    for ci, group in enumerate(chunks, 1):
        lines = [
            f"-- garden-v4-10b-import-payloads-part{ci}.sql — attach JSON payloads (part {ci}/{len(chunks)})",
            "",
        ]
        for p in group:
            data = json.loads(p.read_text(encoding="utf-8"))
            source = f"brainstorm-inbox/import-payloads/{p.name}"
            payload_json = json.dumps(data, ensure_ascii=False).replace("'", "''")
            lines += [
                f"UPDATE public.garden_import_queue SET payload = '{payload_json}'::jsonb,",
                f"  variety_count = {data.get('variety_count', 0)}, status = 'parsed'",
                f"WHERE source_path = '{esc_sql(source)}';",
                "",
            ]
        out = SQL_DIR / f"garden-v4-10b-import-payloads-part{ci}.sql"
        out.write_text("\n".join(lines), encoding="utf-8")
        print(f"Wrote {out.name} ({len(group)} payloads)")

    print(f"Done: {len(files)} payloads in {len(chunks)} SQL parts")


if __name__ == "__main__":
    main()
