# Book recipes — Betty’s process (one book, one recipe at a time)

This document is the **source of truth** for importing cookbook PDFs while you quality-check each recipe.  
Read this before running any `.bat` file in this folder.

---

## What “done” means

A recipe is **not** done when it lands in Pending from a Python script.

A recipe is done when it has gone through **Submit a Recipe** (the full form on the site), you are happy with every field, and you **Approve** it in Admin.

| Stage | Meaning |
|--------|---------|
| **Extract** | PDF → local JSON in `MyCookbook/books/` (draft text only) |
| **Submit a Recipe** | Paste / load → **Parse Recipe** → review **all** fields → Save |
| **Pending** | Waiting for your approval in Admin |
| **Approved** | Live on the site |

**Groq is not used for books.** Do not run `polish_pending.py` for this workflow.  
Optional: Admin **Bulk Autopilot** is mechanical only (not Groq).

---

## Two ways to work (pick one)

### Path A — Full Submit a Recipe (best for learning the standard)

Use this while you are **experimenting** and defining what “good” looks like.

1. Extract the book once (see [One-time setup](#one-time-setup) below).
2. Open a recipe JSON in `MyCookbook/books/` **or** copy text from the PDF.
3. Open **[Submit a Recipe](https://www.theculinaryjournal.site/submit-recipe.html)** (signed in as you).
4. Paste the text → click **✦ Parse Recipe**.
5. Review **every** section: name, category, taxonomy, origin, ingredients, procedure, times, servings, credit, tags.
6. Fix anything wrong in the form (same as a member would).
7. **Submit** → recipe goes to **Pending**.
8. Admin → **Recipe Management → Pending** → open recipe → **✓ Approve** when it matches your standard.

Repeat for the next recipe.

### Path B — Upload skeleton, finish in Submit a Recipe (faster clicks)

Use when extract quality is already decent but you still want the **full form** for every recipe.

1. Run **`.\run_one_recipe.bat`** once → one recipe appears in **Pending**.
2. Admin → Pending → **Edit all fields** (opens Submit a Recipe in admin mode).
3. Fix everything in the form → **Save**.
4. **✓ Approve**.
5. Run **`.\run_one_recipe.bat`** again for the next recipe.

This still ends in the **Submit a Recipe** form — it only skips typing the first paste if extract was good enough.

---

## One-time setup (Lebanese book deep dive)

### 1. Local secrets

```powershell
cd C:\Users\betty\Downloads\Culinary-Journal-main\RecipeExtraction
# Copy setup-env.example.ps1 → setup-env.ps1
# Fill in: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, TCJ_INGEST_USER_ID
# GROQ_API_KEY is NOT required for books
```

### 2. Only one PDF in `inputs/books/`

Keep only the book you are working on (e.g. `Lebanese Home Cooking - Kamal Mouzawak.pdf`).

### 3. Clean old book data in Supabase (once)

Run in Supabase SQL Editor:

`database/sql/fix-clean-non-lebanese-book-recipes.sql`

Preview first, then run the `DELETE` block. This removes **other books’** imports only — not websites or member submissions.

### 4. Extract all recipes to local JSON (once per book refresh)

```powershell
python engines/extract_books.py --refresh "Lebanese Home Cooking - Kamal Mouzawak.pdf"
```

Expect about **50 recipes** for the Lebanese book (Yield-based layout).  
JSON files appear in `MyCookbook/books/`.

Optional local cleanup (removes stale JSON from deleted PDFs):

```powershell
python clean_book_workspace.py
```

---

## Commands reference

| Command | When to use |
|---------|-------------|
| `python engines/extract_books.py --refresh "Your Book.pdf"` | Re-read PDF after parser fixes |
| `python clean_book_workspace.py` | Remove JSON/registry for books not in `inputs/books/` |
| `.\run_one_recipe.bat` | Upload **one** recipe to Pending (no Groq) |
| `.\run_books.bat` | Extract + upload **all** book JSON (no Groq) — use when you trust batch quality |
| `.\run_admin_routine.bat` | Inbox counts only; optional mechanical polish (not Groq) |

**Do not use for books:** `polish_pending.py` (Groq), bulk Groq polish on Vercel.

---

## Admin review (every recipe)

1. Open **Admin → Recipe Management → Pending**.
2. Open a recipe (or use **Edit all fields**).
3. Skim ingredients + procedure against the book.
4. **✓ Approve** or **✕ Reject** (no popup on list reject).
5. **Reject all pending** / **Approve all pending** — one confirmation each; use only when you mean it.

SQL already run once if needed:

- `fix-admin-recipe-full-edit.sql` — full editor save works  
- `fix-admin-approve-all-pending.sql` / `fix-admin-bulk-reject-recipes.sql` — bulk actions  

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|--------|-----|
| `Saved 1 recipe` or junk titles | Old parser / bad extract | Pull latest code; run `--refresh` on the PDF |
| `[SKIP] already processed` | Registry thinks PDF is done | `run_books.bat` now refreshes automatically; or `--refresh` manually |
| `Skip duplicate` on upload | Same recipe still in DB | Delete that book’s rows in SQL, or reject/remove the old row |
| 95 files, `ok=0` | Stale JSON from other books | `python clean_book_workspace.py` |
| Groq out of credits | Book pipeline used to call Groq | **Ignore** — books no longer use Groq |
| PowerShell `run_books.batcd` error | Pasted multiple commands on one line | **One command per line** |

---

## PowerShell rules

Paste **one line at a time**:

```powershell
cd C:\Users\betty\Downloads\Culinary-Journal-main\RecipeExtraction
.\run_one_recipe.bat
```

Do not paste several commands together — PowerShell may merge them into invalid names like `.\run_books.batcd`.

---

## Related docs

| File | Purpose |
|------|---------|
| `ROUTINE.txt` | Short command cheat sheet |
| `inputs/README.txt` | What to drop in each input folder |
| `../docs/IMPORT.md` | Submit a Recipe import paths (URL, paste, scan) |
| `../database/sql/fix-clean-non-lebanese-book-recipes.sql` | Remove non-Lebanese book rows |

---

## Current focus

**Book:** Lebanese Home Cooking — Kamal Mouzawak  
**Mode:** One recipe at a time → **Submit a Recipe** quality → Approve  
**Not in scope:** Groq, auto-approve, multi-book batch until this book meets your standard
