# Admin Review Panel — Agent Autopilot (Betty handles exceptions only)

The agent does the work. Betty's job is **one button + fix yellows**.

---

## Betty's workflow (3 steps, not 14)

| Step | Who | Action |
|------|-----|--------|
| 1 | Betty | Pending tab → **Bulk Autopilot** (or **Agent Review** on one recipe) |
| 2 | Agent | Mechanical cleanup → quality gates → **auto-reject red**; yellow opens editor |
| 3 | Betty | **Only if yellow** — editor popup opens; fix, Save, Approve |

No manual approve for clean recipes. No editor popup for greens. No review of junk — auto-rejected.

---

## Outcome tiers (after mechanical polish + code gates)

| Tier | Meaning | Betty |
|------|---------|-------|
| **Green** | Title, category, ≥2 ingredients, ≥2 steps, real intro, not flagged reject | **Nothing** — auto-approved |
| **Red** | Spam, not a recipe, empty structure, agent `reject_recommended` | **Nothing** — auto-rejected |
| **Yellow** | Fixable gaps (weak intro, unknown ingredients, low confidence but salvageable) | **Edit popup → Save → Approve** |

Missing recipe **images** do **not** block green (book imports approve without photos).

---

## Section-by-section — what the agent does (not Betty)

### 1–2. Header & timing
Agent sets name, category, serves, prep/cook, tags. Betty: nothing if green.

### 3. Buttons
- **Bulk Autopilot** — batch green/red/yellow routing
- **Agent Review** — same logic, one recipe
- **Edit all fields** — manual override only

### 4. Introduction & notes
Agent writes intro; removes import boilerplate. Betty: only if yellow.

### 5. Image
Agent leaves unchanged. No image required for approve.

### 6–7. Ingredients & procedure
Agent splits, sections, formal steps. Betty: only if yellow (unknown names, weak splits).

### 8. Source & credits
Agent fills from import metadata. Betty: rarely.

### 9. Import audit
Agent uses confidence + structure for red vs yellow. Betty: reads summary alert only.

### 10–12. Unknowns & taxonomy
Agent preserves lists; yellow if many unknowns. Betty: fix in editor or approve anyway after edit.

### 13. Quick edit block
Agent pre-fills via save. Betty: optional tweak before approve on yellows.

### 14. Footer Approve/Reject
Agent **auto-clicks** via RPC for green/red. Betty **only** for yellow after edit.

---

## What still cannot be automated

| Item | Why |
|------|-----|
| Token / API limits | Not applicable — mechanical polish only |
| Subjective “is this dish good enough?” | Yellow tier catches edge cases |
| Adding new ingredients to master DB | Governance — agent flags, Betty adds if needed |
| Recipe photos | No image generation |

---

## Cursor agent (same rules)

Use skill + this doc. Run bulk/autopilot, report: **approved / rejected / needs_you** counts — not a 14-step Betty checklist.
