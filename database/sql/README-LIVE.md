# Supabase SQL — live run guide

Use this order on **production** after deploying site code from GitHub.

## Print & Post Phase 1 (after phase31)

| Step | File | Expect |
|------|------|--------|
| 1 | Deploy site code from GitHub | Admin → Finance → **Print Orders** tab; Print Studio **My Print Orders** |
| 2 | `fix-phase53-print-fulfillment.sql` | Run after `fix-phase31-print-orders.sql`; status workflow + RPCs + email templates |
| 3 | Place a test order (signed in) | Order ref on confirmation; row in admin inbox; `print_order_received` queued |

Payment checkout is **not** in this phase — manual fulfilment only.

## Garden Phase 54 (profiles + parser v2 — after go-live)

| Step | File | Expect |
|------|------|--------|
| 1 | Deploy site code from GitHub | Updated parser scripts in repo |
| 2 | `fix-phase54-import-payload-refresh.sql` | 12 refreshed payloads; queue status → parsed for re-apply |
| 3 | `fix-phase54-garden-kitchen-profiles.sql` | 15 kitchen species: care_summary, humid-subtropical care + calendar |
| 4 | Admin → GM Interface → **Import & health** | Apply refreshed imports → publish kitchen batch |

Parser v2 fixes parenthetical docx format (Carrot, Peas, etc.) and adds mangosteen summary cultivars.

## Garden Phase 55 (pages + GM go-live panel)

| Step | File / action | Expect |
|------|---------------|--------|
| 1 | Deploy site code | GM **Import & health** tab shows Kitchen go-live panel |
| 2 | `fix-phase55-garden-pages.sql` | All 4 garden pages `visibility = registered` |
| 3 | GM → Apply refreshed imports → Publish kitchen batch | 15 kitchen species live on directory |

## Garden Phase 56 (Excel 83-field profiles)

| Step | File / action | Expect |
|------|---------------|--------|
| 1 | `python scripts/generate-garden-excel-profiles.py` | Regenerates SQL from `brainstorm-inbox/2025.11.09_Garden.xlsx` |
| 2 | `fix-phase56-garden-excel-profiles.sql` | Tomato species: full plants columns + care rows (humid-subtropical + tropical-monsoon) |
| 3 | GM → publish tomato when curated | Live profile reflects Excel Master Sheet + Quick Plant Profile |

## Garden Phase 57 (PPT + artichoke + guilds/media)

| Step | File / action | Expect |
|------|---------------|--------|
| 1 | Deploy site code | GM Care tab → **Download care-card PPT**; Guilds tab; species media upload |
| 2 | `fix-phase57-garden-artichoke-profile.sql` | Artichoke Purple Romagna Brisbane profile + care + calendar |
| 3 | `fix-phase57-garden-guilds-media.sql` | Guild admin RPCs; sample Mediterranean + brassica guilds (draft) |
| 4 | GM → Guilds → publish when ready; Species → upload hero to garden-media | Media rows in `media` table linked to plants |

## Garden Phase 58 (climate-first copy + public guilds)

| Step | File / action | Expect |
|------|---------------|--------|
| 1 | Deploy site code | Directory shows **Plant guilds** when guilds published in GM |
| 2 | `fix-phase58-garden-climate-copy.sql` | Tomato + artichoke care/profile text uses climate language, not Brisbane/Kerala |
| 3 | Regenerate Excel SQL after inbox edits | `generate-garden-excel-profiles.py` neutralizes city names at export |

**Climate policy:** Member UI filters by `climate_zone` (humid-subtropical, tropical-monsoon). Inbox city labels map at ingest only — never shown on public pages.

## Garden Phase 59 (cultivar climate copy)

| Step | File | Expect |
|------|------|--------|
| 1 | `fix-phase59-garden-cultivar-climate-copy.sql` | All `plant_varieties` text + `variety_climate_suitability.climate_notes` climate-neutral |
| 2 | `fix-phase59-garden-import-queue-payloads.sql` (optional) | Import queue payloads match — prevents re-apply from restoring city labels |

## Garden go-live (step 2j — after v3 + v4)

| Step | File | Expect |
|------|------|--------|
| 1 | `RUN-GARDEN-GO-LIVE.sql` | Garden pages `visibility = registered`; ~208 draft species shells; import queue rows → `approved`; thousands of cultivars in DB |
| 2 | Hard-refresh site + admin | Signed-in members see **The Garden** in nav; directory shows **published** species only (Tomato until you publish more in GM) |
| 3 | Admin → Garden Management → GM Interface | Optional: **Apply all pending imports** if any queue rows remain; publish species when curated |

Or run the three parts separately: `fix-garden-v3-visible.sql`, `garden-v4-14-all-species-shells.sql`, `garden-v4-15-batch-apply-imports.sql`.

## Garden v4 (varieties + climate-first)

| Step | File | Expect |
|------|------|--------|
| 1 | `RUN-GARDEN-V4.sql` | After v3 — status `garden-v4-07-seed-tomato-varieties ready — N varieties`; Tomato shows cultivars on site |

## Quick path (recommended)

| Step | File | Expect |
|------|------|--------|
| 1 | `RUN-LIVE-CLEANUP.sql` | `library_link_summary` with `problems: []`; health RPCs updated |
| 2 | `RUN-ALL-REMAINING.sql` or `RUN-LIVE-FOLLOWUP.sql` | `phase45_summary` or phase 49–51; `health_report.healthy: true` |
| 3 | Hard-refresh admin | System Health matches SQL |
| 4 | `lane2-spot-check.html` | Tick journeys A–F |

## When to use each bundle

| File | Use when |
|------|----------|
| `RUN-IN-SUPABASE-copy-paste-this.sql` | Fresh project or full rebuild (large — ~200KB) |
| `RUN-LIVE-CLEANUP.sql` | Library links + phase43 health RPCs + verify |
| `RUN-ALL-REMAINING.sql` | Full bundle: phases 44–51 + orphan repair + verify |
| `RUN-LIVE-FOLLOWUP.sql` | Phases 49–51 only (if 44–48 already ran) |
| `fix-phase48-recipe-ingredient-orphans.sql` | Orphan recipe ingredient names only |
| `SQL-EDITOR-health-check.sql` | Health check only |
| `fix-phaseNN-*.sql` | Single patch only |

## Regenerate bundles (developers)

```bash
python database/sql/_bundle_for_supabase.py
python database/sql/_bundle_live_cleanup.py
python database/sql/_bundle_remaining.py
```

## Archived (do not run)

See `database/sql/archive/` and `manifest.json` → `archived`.
