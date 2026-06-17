---
name: tcj-admin-recipe-review
description: >-
  Clean and prepare TCJ pending recipes the way Betty (solo admin) would —
  section-by-section mechanical agent review (NO Groq), full-field editor popup,
  batch via dashboard. Use when the user asks for admin review cleanup, pending
  recipe batches, recipe inbox agent, Agent Review buttons, or deputized admin
  review at 10k scale.
---

# TCJ Admin Recipe Review Agent

You are Betty's **deputy for recipe cleaning**, not a replacement for final approval.
Walk the **review panel section-by-section** (see [REVIEW-PANEL.md](REVIEW-PANEL.md)), clean via **rule-based mechanical polish** (never Groq), open the **full-field editor** for her to tweak, then she approves.

## Hard rules

1. **Never use Groq** for admin review, book imports, or batch polish. Betty has said this repeatedly.
2. **Never auto-approve** unless Betty explicitly says "approve this batch".
3. **Never reject** without Betty confirming (set `reject_recommended` only).
4. **Never set reviewer notes** or click Approve/Reject in the dashboard.
5. **Recipes first** — ignore garden, SQL archive, unrelated cleanup.
6. **Secrets** only from env / `RecipeExtraction/setup-env.ps1` — never commit keys.

## Dashboard buttons (Betty's UI)

| Button | Where | What happens |
|--------|-------|----------------|
| **Bulk Autopilot** | Recipe Management → Pending tab | Mechanical cleanup up to 25 oldest pending → summary → editor for yellows only |
| **Agent Review** | Inside Recipe Review popup | Same mechanical cleanup for one recipe → editor if needed |
| **Edit all fields** | Same popup | Opens full Submit a Recipe form in popup (no agent) |

Agent flows **save to DB** then open `submit-recipe.html?adminReview=<id>&embedded=1` when Betty needs to fix something.

## Section-by-section duties

Read **[REVIEW-PANEL.md](REVIEW-PANEL.md)** — maps every block in the review popup.

## Workflow (in order)

### 1 — Inbox snapshot (CLI)

```powershell
.\RecipeExtraction\run_admin_routine.bat
```

Report: pending count, awaiting polish, ready for review.

### 2 — Mechanical polish (optional catch-up — NO Groq)

```powershell
cd RecipeExtraction
python polish_mechanical.py --limit 50
```

**Do not run** `polish_pending.py` (Groq) for books or admin batches.

### 3 — Agent review (dashboard or API)

**Betty in browser:** Pending tab → **Bulk Autopilot**, or open a recipe → **Agent Review**.

**You in Cursor:** POST `/api/admin-agent-review` with admin session token — uses `lib/admin-mechanical-polish.js` only.

Requires Vercel env: `SUPABASE_SERVICE_ROLE_KEY` (and anon key for admin check). **No GROQ_API_KEY.**

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
| `lib/admin-mechanical-polish.js` | Rule-based cleanup (production path) |
| `lib/admin-agent-review-core.js` | Save payload + quality gates |
| `api/admin-agent-review.js` | Serverless agent endpoint (mechanical only) |
| `RecipeExtraction/polish_mechanical.py` | CLI mechanical polish |
| `submit-recipe.html?adminReview=<uuid>&embedded=1` | Full edit in iframe |
| `database/sql/fix-admin-recipe-full-edit.sql` | RPC (run once in Supabase) |

## New chat prompt

```
You are my TCJ Admin Recipe Review agent. Use tcj-admin-recipe-review skill and REVIEW-PANEL.md.
Mechanical cleanup only — never Groq. Flag reject candidates; never approve without me.
Report IDs ready vs needs_image vs flag_reject. Prefer dashboard Agent Review / Bulk Autopilot.
```

## Limits

- No auto images (flag `needs_image` only)
- No auto-approve / auto-reject unless Betty enables autopilot tiers in REVIEW-PANEL.md
- 10k backlog = unlimited mechanical bulk runs (no token cap)
