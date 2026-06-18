# TCJ Recipe Management — Cursor Action Plan

Master checklist mapping Betty's external docs → **this repo's real schema**.

**Reference copies:** `docs/recipe-management-overhaul/` (original Downloads files — do not run SQL from them).

---

## Critical: wrong schema in external SQL

| External (`Database-Schema-Modifications.sql`) | TCJ production |
|----------------------------------------------|----------------|
| `recipes` | **`submitted_recipes`** |
| `recipes.name` | **`recipe_name`** |
| `is_visible` boolean | **`visibility`** text (`Public`, …) |
| `subcategories` / `divisions` (FK) | **`recipe_subcategories`** / **`recipe_divisions`** |
| `is_archived` | **`is_active = false`** |

**Never paste** `Database-Schema-Modifications.sql` into Supabase as-is.

---

## What's live vs what's not

| Item | Status |
|------|--------|
| Phase 1 SQL (`fix-taxonomy-archive-phase1.sql`) | Betty ran triggers ✅ |
| Phase 1 JS (cache clear, merge fix, Remove) | **Live** — Taxonomy tab |
| **Bulk Editor tab** | **Live after deploy** — run `fix-admin-bulk-recipes.sql` first |
| Export taxonomy JSON + CSV | Taxonomy tab buttons |

**How to confirm deploy:** Recipe Management → **⚙ RM Interface** → sidebar **Taxonomy** → intro line says **Taxonomy editor v20260619a** and gold **Export taxonomy (JSON)** button.

**Remove button:** expand a category → each sub row has red **Remove** on the right (no need to expand the sub).

---

## Phase 1 — Critical path (DO FIRST)

### Betty — Supabase (once)

1. `database/sql/fix-admin-taxonomy-editor.sql` (if RPC errors)
2. `database/sql/fix-taxonomy-archive-phase1.sql` ✅ done

### Betty — Test delete sticks

1. Hard-refresh dashboard (**Ctrl+Shift+R**)
2. **Recipe Management → ⚙ RM Interface → Taxonomy**
3. Expand a category → click red **Remove** on a throwaway sub
4. Refresh Taxonomy tab → sub **stays gone**
5. Do **not** click **Sync from book** afterward (that re-creates book subs)

### If test fails

| Symptom | Fix |
|---------|-----|
| Sub reappears | Red RPC banner? Re-run admin taxonomy SQL. Accidentally used Sync from book? |
| No Remove button | Hard refresh; check version string v20260619a |
| Remove errors | Re-run phase 1 SQL |

### Cursor — Phase 1 code

- [x] `fix-taxonomy-archive-phase1.sql`
- [x] `rmTaxMergeSubs(..., { bookFillMissing: !rpcOk })`
- [x] `rmTaxClearTaxonomyCaches()` in `loadRMTaxonomy()`
- [x] **Remove** on sub header row
- [x] Export taxonomy JSON (client-side from RPC rows)

---

## Phase 2 — Bulk Recipe Editor

Maps to `Bulk-Editor-Implementation-Code.md` + external SQL steps 4–12.

### Betty — Supabase

Run **`database/sql/fix-admin-bulk-recipes.sql`** (to be added) — extends `submitted_recipes`, not `recipes`.

### Cursor

1. Tab **📋 Bulk Editor** on Recipe Management row (not RM Interface sidebar)
2. Wire `admin_get_recipes_bulk` → **`submitted_recipes`** via adapted RPC
3. Fields: `recipe_name`, `recipe_code`, category, sub_category, division, `visibility`, status
4. RM# format: `RM20260619001` (per external spec)

### Phase 2 checklist

- [ ] Tab loads
- [ ] Search / filter / sort
- [ ] Inline edit saves
- [ ] RM# generation
- [ ] Show/hide (`visibility`)
- [ ] CSV export
- [ ] Pagination

---

## Phase 3 — Audit & polish

- `recipe_taxonomy_audit` on `submitted_recipes` (adapted from external Step 5–6)
- Cascading rename when sub/division text changes
- Optional: `scripts/reconcile_taxonomy.py`

---

## SQL run order

| Step | File |
|------|------|
| Done | category seeds, `fix-seed-hint-divisions.sql`, `fix-book-taxonomy.sql` |
| Required | `fix-admin-taxonomy-editor.sql` |
| Phase 1 | **`fix-taxonomy-archive-phase1.sql`** |
| Phase 2 | **`fix-admin-bulk-recipes.sql`** (pending) |

---

## Root cause (subs “came back”)

1. **`rmTaxMergeSubs`** re-added book defaults when RPC succeeded — fixed.
2. **Sync from book** still re-creates all book subs — avoid after manual removes.
3. Archive = **`is_active = false`**, not hard delete.

---

## External doc index

| File | Use |
|------|-----|
| `CURSOR-ACTION-PLAN-original.md` | Full timeline & test suites |
| `Database-Schema-Modifications-original.sql` | Intent only — wrong tables |
| `TCJ-Recipe-Management-Overhaul-original.md` | Strategy / root cause |
| `Bulk-Editor-Implementation-Code-original.md` | Phase 2 HTML/JS templates |

*Updated: integrated Betty's Downloads docs; v20260619a UX + export.*
