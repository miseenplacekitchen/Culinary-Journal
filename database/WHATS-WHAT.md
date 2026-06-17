# Database SQL — What Betty Actually Needs

**Ignore everything in `sql/archive/`** unless a developer asks you to restore something.

---

## Three categories only

### 1. Fresh project (never needed again — your site is already live)

| File | When |
|------|------|
| `../full-setup.sql` | Brand-new Supabase project only |

Built from the 25 **core** files in `sql/` (01-schema through fix_anon_grants).

---

### 2. Recipe pipeline (you — now)

| File | When |
|------|------|
| `sql/fix-recipe-batch-ingest.sql` | Once ✅ — allows batch upload |
| `sql/fix-website-sources.sql` | Once ✅ — website scrape sources |
| `sql/fix-admin-inbox-counts.sql` | Admin dashboard badges |
| `sql/fix-admin-recipe-full-edit.sql` | **Once** — full admin edit (ingredients, procedure, all fields) |

---

### 4. Taxonomy (book + Sips — run when structure changes)

| File | When |
|------|------|
| `sql/fix-book-taxonomy.sql` | **Re-run** after book taxonomy updates — 12 food categories (not Garden, not Sips). Ends with verify query. |
| `sql/fix-sips-drinks-taxonomy.sql` | **Re-run** after Sips Parts A–D updates — 21 subs, 92 divisions. Safe to re-run. |

Source of truth: `taxonomy/book-taxonomy.md` (12 categories) + `sql/fix-sips-drinks-taxonomy.sql` (Sips).  
Regenerate SQL/JS: `python database/taxonomy/generate_taxonomy_sql.py`  
Validate infer rules: `python database/taxonomy/validate_food_infer.py` and `validate_drink_infer.py`  
Audit site wiring: `python database/taxonomy/audit_taxonomy.py`

**Garden & Earth** uses the dishes table in Supabase — do not seed from fix-book-taxonomy.sql unless explicitly planned.

---

### 3. Live site bundles (already applied — do not re-run unless told)

These were pasted into Supabase during build-out. **You do not hunt through 180 files anymore.**

| File | Purpose |
|------|---------|
| `RUN-LIVE-CLEANUP.sql` | Library links + health RPCs |
| `RUN-ALL-REMAINING.sql` | Phases 44–48 + health |
| `RUN-LIVE-FOLLOWUP.sql` | Phases 49–51 |
| `RUN-LIVE-PHASE52.sql` | Phase 52 library + sample recipes |
| `RUN-GARDEN-V3.sql` | Garden foundation |
| `RUN-GARDEN-V3-POLISH.sql` | Garden polish |
| `RUN-GARDEN-V4.sql` | Garden cultivars + import queue |
| `RUN-GARDEN-GO-LIVE.sql` | Garden public pages |
| `SQL-EDITOR-health-check.sql` | Verify `healthy: true` |

Individual `fix-phase39-*.sql` through `fix-phase59-*.sql` files are **slices** of those bundles — use only if a developer says “run fix-phase48 only”.

---

## Folder layout (after cleanup)

```
database/
  WHATS-WHAT.md          ← this file
  MAP.md                 ← developer reference
  manifest.json          ← machine map
  full-setup.sql         ← fresh install only
  build-setup.py         ← regenerates full-setup
  sql/
    01-schema.sql …      ← 25 core modules
    RUN-*.sql            ← live bundles (reference)
    fix-recipe-batch-ingest.sql
    fix-website-sources.sql
    fix-phase39-*.sql …  ← incremental patches (reference)
    archive/             ← OLD / redundant — do not run
      historical-phases/
      garden-modules/
      generated/
      dev-tools/
```

---

## Rule of thumb

- **Recipe import broken?** → `fix-recipe-batch-ingest.sql` or ask support  
- **Health check failing?** → `SQL-EDITOR-health-check.sql`  
- **Something else?** → ask before running random `fix-phase*.sql` from archive  
