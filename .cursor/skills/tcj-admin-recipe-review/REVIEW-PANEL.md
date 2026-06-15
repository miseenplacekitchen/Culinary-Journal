# Admin Review Panel — Section-by-Section Agent Playbook

Betty's deputy agent walks the **same sections** as the Recipe Review popup, in order.
The agent **cleans and saves**; Betty **approves** (never auto-approve unless she says so).

---

## 1. Header — identity & status

| Field | Agent does |
|-------|------------|
| Recipe name | Title Case; remove PDF junk (`POUL TRY`, page numbers, run-on codes) |
| Also known as | Keep if in source; else leave empty |
| Status badge | **Do not change** (stays Pending until Betty approves) |
| Category tag | Pick single best TCJ category |
| Origin / spice tags | Set from cleaned metadata |

---

## 2. Submitter & timing row

| Field | Agent does |
|-------|------------|
| Submitted by / date | Read-only — no change |
| Serves | Parse from "Serves N" in source |
| Prep / Cook minutes | From source or 0 if unknown |

---

## 3. Agent actions bar (buttons)

| Button | Agent does |
|--------|------------|
| **Agent Review (this recipe)** | Runs Groq full clean → saves → opens **Edit all fields** popup |
| **Edit all fields** | Opens Submit a Recipe form (no agent run) |
| **Bulk Agent Review** | Runs agent on oldest N pending (max 25/batch) |

---

## 4. Introduction & cooking notes

| Field | Agent does |
|-------|------------|
| Introduction | Write 1–2 professional sentences; remove boilerplate "Imported from…" only text |
| Cooking notes | Tips not repeated in steps; empty if none in source |

---

## 5. Recipe image

| Field | Agent does |
|-------|------------|
| Image | **Does not generate images** — leaves `image_url` unchanged |
| Flag | Notes `needs_image` in agent_notes for book imports without photos |

---

## 6. Ingredients (preview in panel)

| Field | Agent does |
|-------|------------|
| Sections | Preserve sub-sections (Spice Paste, Garnish, etc.) |
| Each row | Split qty, unit, ingredient, note |
| Governed names | Match TCJ ingredient database when obvious |
| Unknown list | Populate `unknown_ingredients` for names not in DB |

Betty: use **Edit all fields** popup to fix rows the agent missed.

---

## 7. Procedure (preview in panel)

| Field | Agent does |
|-------|------------|
| Sections | PREP WORK / DIRECTIONS when source supports |
| Steps | ≥2 steps; `{ title, text }`; formal English |
| Logic | Same cooking logic as source — no invented steps |
| Flag | Sets `procedure_rewritten = true` |

---

## 8. Source & credits

| Field | Agent does |
|-------|------------|
| Source type | Book / Website / Social / Original from import path |
| Credit name | Book title or site name |
| Credit handle | Instagram @ if reel import |
| Credit URL | `import_source_url` when present |

---

## 9. Import audit (read-only context)

| Field | Agent does |
|-------|------------|
| Parser / confidence | Uses low confidence + empty structure → `reject_recommended` |
| Warnings | Reads warnings; fixes split issues when possible |
| Raw text | Reference only — do not paste into live fields |

**Reject candidates:** not a recipe, spam, empty ingredients+method, duplicate obvious junk.

---

## 10. Unknown ingredients ⚠

| Agent does |
|------------|
| Lists names not in governed DB |
| Does **not** auto-add to Ingredients admin — Betty clicks + Add or ignores |

---

## 11. Unknown tools ⚠

| Agent does |
|------------|
| Preserves `unknown_utensils` |
| Betty handles via Tools admin or library submit |

---

## 12. Suggested taxonomy ⚠

| Agent does |
|------------|
| Preserves `taxonomy_suggestions` |
| May infer sub_category/division in full save when confident |
| Betty adds to taxonomy master list when needed |

---

## 13. Quick edit block (panel form)

| Field | Agent does |
|-------|------------|
| Name, native, category, spice, sweet | Same as full agent pass |
| Servings, prep, cook, origin | Filled in agent pass |
| Intro & cooking notes textareas | Updated in DB by agent |

Betty can still tweak here before Approve without opening full form.

---

## 14. Review footer (Betty only)

| Field | Agent does |
|-------|------------|
| Rejection reason | **Never set** |
| Reviewer notes | **Never set** |
| Approve / Reject / Feature | **Never click** — Betty only |

---

## Workflow summary

```
Import (7 sources) → Groq polish (pipeline) → Agent Review (dashboard)
    → Edit all fields popup (if needed) → Betty Approve
```

**Groq limit:** Bulk Agent Review max 25/run; repeat daily for 10k backlog.

**Hosting:** Set `GROQ_API_KEY` and `SUPABASE_SERVICE_ROLE_KEY` on Vercel (or host) for `/api/admin-agent-review`.
