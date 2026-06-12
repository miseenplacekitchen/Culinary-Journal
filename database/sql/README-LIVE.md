# Supabase SQL — live run guide

Use this order on **production** after deploying site code from GitHub.

## Quick path (recommended)

| Step | File | Expect |
|------|------|--------|
| 1 | `RUN-LIVE-CLEANUP.sql` | `library_link_summary` with `problems: []`; health RPCs updated |
| 2 | `RUN-ALL-REMAINING.sql` | `phase45_summary`; final `health_report.healthy: true` |
| 3 | Hard-refresh admin | System Health matches SQL |
| 4 | `lane2-spot-check.html` | Tick journeys A–F |

## When to use each bundle

| File | Use when |
|------|----------|
| `RUN-IN-SUPABASE-copy-paste-this.sql` | Fresh project or full rebuild (large — ~200KB) |
| `RUN-LIVE-CLEANUP.sql` | Library links + phase43 health RPCs + verify |
| `RUN-ALL-REMAINING.sql` | Phase 44–48 library + site fill + orphan repair + verify |
| `fix-phase48-recipe-ingredient-orphans.sql` | Orphan recipe ingredient names only (if health shows orphans) |
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
