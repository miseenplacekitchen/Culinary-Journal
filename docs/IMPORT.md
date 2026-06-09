# How to import a recipe (contributors)

## URL import (preferred)

1. Open **Submit a Recipe** while signed in.
2. Paste a **direct recipe page URL** (not a homepage or category page).
3. Click **Import**. Wait for the import report (ingredient count, step count, warnings).
4. Review every field — especially **ingredients**, **method**, **category**, and **dietary tags**.
5. Uncheck any auto-filled tags that are wrong. Low-confidence imports do **not** auto-fill category/tags.
6. Add **credit name** and confirm **source URL** when source is not Original.
7. Upload a photo if you have one, then submit.

## When to paste manually

- The site blocked automated fetch (Allrecipes, Taste, etc.).
- Import shows fewer than 2 ingredients or steps.
- The page is social-only (Instagram/TikTok) without full recipe text in the caption.

Copy the recipe text into the paste box, add clear `Ingredients` and `Method` headings if missing, then click **Parse Recipe**.

## Photo / PDF scan

Use for cookbook pages or handwritten cards. Choose a flat, well-lit photo. PDFs are read up to **8 pages** (longer PDFs are truncated — paste the rest manually).

## Start fresh (`?new=1`)

Use **Start fresh import** or open `submit-recipe.html?new=1` to clear local and cloud drafts before a new URL import. Use this if a previous import left bad data in the form.

## Generate starter vs URL import

- **Import** pulls real text from a blog URL (verify against source).
- **Generate starter** fabricates a template from the dish name only — not a real recipe.

## Auto-filled tags

When import confidence is high (70+), category, tags, and times may be suggested. They are **estimates**. Wrong allergen tags affect public safety — always verify.

## Admin import audit

Submitted imports store parser version, confidence, warnings, paste snapshot, and source URL. Reviewers can compare snapshot vs submitted JSON in the admin panel.
