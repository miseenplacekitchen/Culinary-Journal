# TCJ Recipe Management — Cursor Action Plan

Master checklist for Betty + Cursor. **Do not run the raw files in `Downloads/` unchanged** — they assume tables named `recipes`, `subcategories`, `divisions`. TCJ uses `submitted_recipes`, `recipe_subcategories`, `recipe_divisions`, `categories`.

| External doc | TCJ equivalent |
|--------------|----------------|
| `Database-Schema-Modifications.sql` steps 1–3 | **`database/sql/fix-taxonomy-archive-phase1.sql`** |
| `Database-Schema-Modifications.sql` steps 4–12 | **`database/sql/fix-admin-bulk-recipes.sql`** (Phase 2 — not started until Phase 1 test passes) |
| `Bulk-Editor-Implementation-Code.md` | **`dashboard.html` + `dashboard-recipes.js`** (Phase 2) |
| `TCJ-Recipe-Management-Overhaul.md` | Strategy reference only |

**Archive flag:** TCJ already uses `is_active = false` (not `is_archived`). Phase 1 adds indexes + delete guards; it does **not** duplicate columns.

---

## Phase 1 — Critical path (DO THIS FIRST)

### Betty — Supabase (once)

1. Run **`database/sql/fix-taxonomy-archive-phase1.sql`**
2. Confirm output: `get_recipe_taxonomy` exists; delete guard triggers listed

### Betty — Verify delete sticks

1. Hard-refresh dashboard (**Ctrl+Shift+R**)
2. **Recipe Management → RM Interface → Taxonomy**
3. Expand a category with a **non-canonical test sub** (or add a throwaway sub, save it)
4. Click **Remove** on that sub → confirm
5. Refresh the Taxonomy tab → sub must **stay gone**
6. Public **Recipes → browse** that category → sub must **not** reappear

### If test fails

| Symptom | Check |
|---------|--------|
| Sub reappears after refresh | Was RPC OK? (no red banner). Book merge only fills when RPC fails. |
| Remove button missing | Deploy latest `dashboard-recipes.js` |
| RPC error | Re-run `fix-admin-taxonomy-editor.sql` then `fix-taxonomy-archive-phase1.sql` |
| Sub in Supabase still `is_active = true` | `admin_delete_recipe_subcategory` not deployed — re-run Phase 1 SQL |

### Cursor — Phase 1 code (done in repo)

- [x] `fix-taxonomy-archive-phase1.sql` — indexes, delete guards, deactivate RPCs
- [x] `loadRMTaxonomy()` — clear stale taxonomy cache keys; RPC-success → **no book backfill** of removed subs
- [x] **Remove sub-category** button in Taxonomy admin
- [x] `rmTaxMergeSubs(..., { bookFillMissing: !rpcOk })`

**Do not proceed to Phase 2 until Betty confirms Phase 1 test passes.**

---

## Phase 2 — Bulk Recipe Editor (after Phase 1 ✅)

Reference: `Bulk-Editor-Implementation-Code.md` + `Database-Schema-Modifications.sql` steps 4–12.

### Betty — Supabase

1. Run **`database/sql/fix-admin-bulk-recipes.sql`** (when added)

### Cursor

1. New tab **Bulk Editor** in `dashboard.html`
2. Wire to **`admin_get_recipes`** (extended) — not `admin_get_recipes_bulk` on a fake `recipes` table
3. Inline edit via **`admin_edit_recipe`** / bulk RPC
4. Fields: `recipe_name`, `recipe_code`, category, sub_category, division, `visibility`, status

### Phase 2 test checklist (from Bulk-Editor doc)

- [ ] Bulk Editor tab loads
- [ ] Search / category filter
- [ ] Column sort
- [ ] Inline edit saves
- [ ] RM# generation
- [ ] Bulk show/hide (visibility)
- [ ] CSV export
- [ ] Pagination

---

## Phase 3 — Export & audit (optional)

- Taxonomy export (CSV/JSON from `get_recipe_taxonomy`)
- `submitted_recipes` taxonomy change audit table

---

## SQL run order (full production, when all phases ready)

| Step | File |
|------|------|
| Already done | `fix-categories-v2.sql`, category seeds, `fix-seed-hint-divisions.sql`, `fix-book-taxonomy.sql` |
| Required | `fix-admin-taxonomy-editor.sql` |
| **Phase 1** | **`fix-taxonomy-archive-phase1.sql`** |
| Phase 2 | `fix-admin-bulk-recipes.sql` |

**Never run:** `Downloads/Database-Schema-Modifications.sql` (wrong schema).

---

## Root cause (why subs “came back”)

1. **`rmTaxMergeSubs`** re-injected every book default sub not returned by RPC — deactivated subs looked “deleted” in DB but reappeared in admin UI.
2. **Book generator** overwrote `taxonomy-parts.js` (fixed in `449a393` + `tcj-migrated-taxonomy-parts.js`).
3. **`is_active = false`** is the archive; rows remain in DB for recovery (by design).

---

*Last updated: Phase 1 implementation — run SQL then test before Bulk Editor.*
