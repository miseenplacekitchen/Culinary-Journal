# Database SQL — What Betty Actually Needs

**Ignore `sql/archive/`** unless a developer explicitly tells you to restore something.

---

## Taxonomy (A–K) — run order

Run each file **once** in Supabase SQL Editor, in this order:

| Step | File | What it does |
|------|------|----------------|
| 1 | `sql/fix-categories-v2.sql` | Eleven A–K categories |
| 2 | `sql/fix-category-cleanup-v3.sql` | Tags, baby browse, Stripe idempotency |
| 3 | `sql/fix-admin-taxonomy-editor.sql` | **Browse + admin RPCs** (run before editing taxonomy in dashboard) |
| 4 | `sql/fix-garden-taxonomy-v2.sql` | Garden A1–A13 |
| 5b | `sql/fix-feather-pasture-b8-c8.sql` | Once — Feather B8 + Pasture C8 offal subs (incremental; safe after you added subs in admin) |
| 5 | `sql/fix-feather-pasture-taxonomy.sql` | Feather B + Pasture C (full seed — only on fresh DB) |
| 6 | `sql/fix-ocean-river-taxonomy.sql` | Ocean D |
| 7 | `sql/fix-grain-field-taxonomy.sql` | Grain Field E |
| 8 | `sql/fix-sips-stories-taxonomy.sql` | Sips J |
| 9 | `sql/fix-seed-hint-divisions.sql` | **Required** — turns ingredient hints into browse divisions (Potatoes, Drumsticks, etc.) |
| 10 | `sql/fix-book-taxonomy.sql` | Wrapped, Curds, Breads, Sweet, Preserved — full book subs + divisions |

**Do not run** `sql/fix-deactivate-legacy-taxonomy.sql` (retired — it removed divisions).

After step 3, edit subs/divisions in **Dashboard → Taxonomy**. JS book defaults (`lib/tcj-*-taxonomy.js`) are seed/reference only — the database is what the live site uses.

**Never run** anything in `sql/archive/superseded-2026/` (old 12-category book tree, old Sips 21-sub tree, duplicate RPC patches).

---

## Recipe pipeline

| File | When |
|------|------|
| `sql/fix-recipe-batch-ingest.sql` | Once — batch upload |
| `sql/fix-website-sources.sql` | Once — website scrape sources |
| `sql/fix-admin-inbox-counts.sql` | Admin dashboard badges |
| `sql/fix-admin-recipe-full-edit.sql` | Once — full admin recipe edit |

---

## Security (once)

| File | When |
|------|------|
| `sql/fix-security-rpcs.sql` | Harden admin RPCs |
| `sql/fix-login-info-leak.sql` | Drop `is_admin` from pre-auth login |
| `sql/fix-recipe-discovery-rpcs.sql` | Festival / wellness browse |
| `sql/migrate-feast-nourish-categories.sql` | Feast / Nourish → tags |

---

## Fresh project only

| File | When |
|------|------|
| `../full-setup.sql` | Brand-new Supabase project |

---

## Rule of thumb

- **Taxonomy browse or admin save broken?** → Run `fix-admin-taxonomy-editor.sql`
- **New category subs from Betty's paste?** → One `fix-*-taxonomy.sql` per category (steps 4–8 pattern)
- **Something else?** → Ask before running files from `archive/`
