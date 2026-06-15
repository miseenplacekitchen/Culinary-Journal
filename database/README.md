# Database SQL Source

Single source of truth for The Culinary Journal Supabase schema, RPCs, policies, and seed data.

## Betty — start here

**`WHATS-WHAT.md`** — which SQL files matter for you (3 categories).  
Ignore `sql/archive/` unless a developer asks.

## Quick start — one run, no manual script hunting

```text
1. Open Supabase Dashboard → SQL Editor
2. Paste database/full-setup.sql
3. Run once
```

Regenerate after editing any module:

```bash
python database/build-setup.py
```

## Folder layout

```
database/
├── MAP.md           ← human-readable database map
├── manifest.json    ← canonical run order + function owners
├── full-setup.sql   ← generated full setup (commit this)
├── build-setup.py   ← rebuild full-setup.sql from manifest
├── INDEX.md         ← per-file function inventory
└── sql/
    ├── *.sql        ← canonical modules (one owner per function)
    └── archive/     ← deprecated — DO NOT RUN
```

## How to change the database

1. Find the **owning file** in `MAP.md` or `manifest.json` → `function_owners`
2. Edit that file only
3. Run `python database/build-setup.py`
4. Commit the module + regenerated `full-setup.sql`
5. Apply the **changed section** to live Supabase (or re-run full setup on staging)

## What changed

- **Before:** 30+ scattered files, many duplicates, manual paste of individual scripts
- **After:** `manifest.json` defines order, `full-setup.sql` deploys everything once, duplicates archived under `sql/archive/`

## Safety

- Never run files in `sql/archive/`
- Never run `00-drop-functions.sql` against production
- `full-setup.sql` is idempotent where possible (`IF NOT EXISTS`, `CREATE OR REPLACE`)
- Live production changes should still be reviewed — use staging first
