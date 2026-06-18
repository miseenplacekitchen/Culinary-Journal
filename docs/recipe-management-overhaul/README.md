# Recipe Management Overhaul — Reference Docs

These files came from Betty's Downloads folder. They describe the **intent** of the overhaul. **Do not run the SQL or paste the JS verbatim** — they target a fictional schema (`recipes`, `subcategories`, `is_archived`).

## TCJ reality

| External doc assumes | TCJ uses |
|---------------------|----------|
| `recipes` | `submitted_recipes` |
| `recipes.name` | `submitted_recipes.recipe_name` |
| `is_visible` boolean | `visibility` text (`Public`, `Registered`, …) |
| `subcategories` + FK | `recipe_subcategories` (text `category` name) |
| `divisions` + FK | `recipe_divisions` |
| `is_archived` | `is_active = false` (archive) |

## What to run instead

| Phase | Betty runs | Cursor deploys |
|-------|------------|----------------|
| 1 | `database/sql/fix-taxonomy-archive-phase1.sql` | `dashboard-recipes.js` (Remove sub, cache clear, merge fix) |
| 2 | `database/sql/fix-admin-bulk-recipes.sql` (when ready) | Bulk Editor tab in `dashboard.html` |
| 3 | same Phase 2 SQL (export RPC) | Export Taxonomy button |

**Master checklist:** [`CURSOR-ACTION-PLAN.md`](../../CURSOR-ACTION-PLAN.md) at repo root.

## Files in this folder

- `CURSOR-ACTION-PLAN-original.md` — full step-by-step from external author
- `Database-Schema-Modifications-original.sql` — **reference only, wrong table names**
- `TCJ-Recipe-Management-Overhaul-original.md` — strategy / root cause write-up
- `Bulk-Editor-Implementation-Code-original.md` — HTML/JS templates for Phase 2
