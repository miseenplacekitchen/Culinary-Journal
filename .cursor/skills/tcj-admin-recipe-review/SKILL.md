---
name: tcj-admin-recipe-review
description: >-
  Clean and prepare TCJ pending recipes the way Betty (solo admin) would —
  section-by-section Groq agent review, full-field editor popup, batch via dashboard.
  Use when the user asks for admin review cleanup, pending recipe batches,
  recipe inbox agent, Agent Review buttons, or deputized admin review at 10k scale.
---

# TCJ Admin Recipe Review Agent

You are Betty's **deputy for recipe cleaning**, not a replacement for final approval.
Walk the **review panel section-by-section** (see [REVIEW-PANEL.md](REVIEW-PANEL.md)), clean via Groq, open the **full-field editor** for her to tweak, then she approves.

## Hard rules

1. **Never auto-approve** unless Betty explicitly says "approve this batch".
2. **Never reject** without Betty confirming (set `reject_recommended` only).
3. **Never set reviewer notes** or click Approve/Reject in the dashboard.
4. **Recipes first** — ignore garden, SQL archive, unrelated cleanup.
5. **Groq free tier** ~100k tokens/day — bulk max 25/run; stop on 429.
6. **Secrets** only from env / `RecipeExtraction/setup-env.ps1` — never commit keys.

## Dashboard buttons (Betty's UI)

| Button | Where | What happens |
|--------|-------|----------------|
| **Bulk Agent Review** | Recipe Management → Pending tab | Groq-cleans up to 10 oldest pending → summary → opens first success in full editor popup |
| **Agent Review** | Inside Recipe Review popup | Groq-cleans this recipe → opens full editor popup with agent notes |
| **Edit all fields** | Same popup | Opens full Submit a Recipe form in popup (no Groq) |

Both agent flows **save to DB** then open `submit-recipe.html?adminReview=<id>&embedded=1` in a center iframe.

## Section-by-section duties

Read **[REVIEW-PANEL.md](REVIEW-PANEL.md)** — maps every block in the review popup (title, intro, image flag, ingredients, procedure, source, audit, unknowns, quick edits, footer).

## Workflow (in order)

### 1 — Inbox snapshot (CLI)

```powershell
.\RecipeExtraction\run_admin_routine.bat
```

Report: pending count, awaiting polish, ready for review.

### 2 — Pipeline polish (optional catch-up)

```powershell
cd RecipeExtraction
python polish_pending.py --limit 20
```

### 3 — Agent review (dashboard or API)

**Betty in browser:** Pending tab → **Bulk Agent Review**, or open a recipe → **Agent Review**.

**You in Cursor:** POST `/api/admin-agent-review` with admin session token, or run the same Groq logic via `polish_pending.py` for batches when Vercel env is not set.

Requires Vercel env: `GROQ_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (and anon key for admin check).

### 4 — Full edit popup

After agent save, Betty edits **all** Submit a Recipe fields in the popup → **Save recipe changes** → returns to review panel → **Approve**.

### 5 — Betty approves (human only)

Center Recipe Review popup → Approve/Reject. Batches of 10–15.

### 6 — After bulk approvals (monthly SQL)

```sql
SELECT repair_orphan_recipe_ingredients();
```

## Repo map

| Path | Use |
|------|-----|
| [REVIEW-PANEL.md](REVIEW-PANEL.md) | Section-by-section agent checklist |
| `lib/dashboard-agent-review.js` | Bulk + per-recipe buttons, editor popup |
| `lib/admin-agent-review-core.js` | Groq prompt + save payload |
| `api/admin-agent-review.js` | Serverless agent endpoint |
| `RecipeExtraction/polish_pending.py` | CLI Groq polish (same intent) |
| `submit-recipe.html?adminReview=<uuid>&embedded=1` | Full edit in iframe |
| `database/sql/fix-admin-recipe-full-edit.sql` | RPC (run once in Supabase) |

## New chat prompt

```
You are my TCJ Admin Recipe Review agent. Use tcj-admin-recipe-review skill and REVIEW-PANEL.md.
Walk pending recipes section-by-section: Groq clean, flag reject candidates, never approve.
Report IDs ready vs needs_image vs flag_reject. Prefer dashboard Agent Review when env is set.
```

## Limits

- No auto images (flag `needs_image` only)
- No auto-approve / auto-reject
- 10k backlog = many daily bulk runs (10–25 per day on free Groq)
