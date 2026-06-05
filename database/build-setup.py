#!/usr/bin/env python3
"""Build database/full-setup.sql from manifest.json setup_order."""
import json
import os
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.abspath(__file__))
SQL_DIR = os.path.join(ROOT, 'sql')
ARCHIVE_DIR = os.path.join(SQL_DIR, 'archive')
MANIFEST = os.path.join(ROOT, 'manifest.json')
OUTPUT = os.path.join(ROOT, 'full-setup.sql')


def main():
    with open(MANIFEST, encoding='utf-8') as f:
        manifest = json.load(f)

    parts = [
        '-- ' + '=' * 70,
        '-- THE CULINARY JOURNAL — FULL DATABASE SETUP',
        f'-- Generated: {datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")}',
        '-- Source: database/manifest.json → database/build-setup.py',
        '--',
        '-- Run this ONCE in Supabase Dashboard → SQL Editor on a fresh project.',
        '-- Do NOT run 00-drop-functions.sql or archived files.',
        '-- ' + '=' * 70,
        '',
    ]

    for entry in manifest['setup_order']:
        fname = entry['file']
        path = os.path.join(SQL_DIR, fname)
        if not os.path.isfile(path):
            alt = os.path.join(ARCHIVE_DIR, fname)
            if os.path.isfile(alt):
                path = alt
            else:
                raise FileNotFoundError(f'Missing SQL file: {fname}')
        with open(path, encoding='utf-8') as f:
            body = f.read().strip()
        parts.append(f'\n-- {"─" * 66}')
        parts.append(f'-- FILE: sql/{fname}  [{entry.get("layer", "?")}] owner={entry.get("owner", "?")}')
        if entry.get('note'):
            parts.append(f'-- NOTE: {entry["note"]}')
        parts.append(f'-- {"─" * 66}\n')
        parts.append(body)
        parts.append('')

    parts.append('\n-- END OF FULL SETUP\n')

    with open(OUTPUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(parts))

    print(f'Wrote {OUTPUT} ({len(manifest["setup_order"])} modules)')


if __name__ == '__main__':
    main()
