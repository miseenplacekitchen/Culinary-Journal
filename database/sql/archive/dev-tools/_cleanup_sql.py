#!/usr/bin/env python3
"""One-time SQL folder cleanup — moves redundant files to archive/."""
from __future__ import annotations

import shutil
from pathlib import Path

SQL = Path(__file__).resolve().parent / "sql"
ARCHIVE = SQL / "archive"
HIST = ARCHIVE / "historical-phases"
GARDEN = ARCHIVE / "garden-modules"
GENERATED = ARCHIVE / "generated"
DEV = ARCHIVE / "dev-tools"

KEEP = {
    # Canonical setup (manifest setup_order)
    "01-schema.sql",
    "sync-submitted-recipes-columns.sql",
    "02-functions.sql",
    "03-seed.sql",
    "04-auth-triggers.sql",
    "05-diary.sql",
    "06-culinary-life.sql",
    "table_planner.sql",
    "setup-collections.sql",
    "setup-family-profiles.sql",
    "notification_rpcs.sql",
    "recipe_management.sql",
    "user_management.sql",
    "recipe_notes.sql",
    "grocery_list.sql",
    "pantry.sql",
    "meal_planner.sql",
    "library-profiles.sql",
    "library_rls.sql",
    "email_templates.sql",
    "finance_tables.sql",
    "sm_rpc_functions.sql",
    "sm_compat_rpcs.sql",
    "fix_rls_recursion.sql",
    "fix_anon_grants.sql",
    # Live site bundles (run once on production, in order documented in WHATS-WHAT.md)
    "RUN-LIVE-CLEANUP.sql",
    "RUN-ALL-REMAINING.sql",
    "RUN-LIVE-FOLLOWUP.sql",
    "RUN-LIVE-PHASE52.sql",
    "RUN-GARDEN-V3.sql",
    "RUN-GARDEN-V3-POLISH.sql",
    "RUN-GARDEN-V4.sql",
    "RUN-GARDEN-GO-LIVE.sql",
    "SQL-EDITOR-health-check.sql",
    "RUN-PHASE59-IMPORT-QUEUE-PAYLOADS.txt",
    "README-LIVE.md",
    # Active Betty patches (recipe pipeline + admin)
    "fix-recipe-batch-ingest.sql",
    "fix-website-sources.sql",
    "fix-admin-inbox-counts.sql",
    # Incremental production patches (phase 39+)
    "fix-phase39-data-integrity.sql",
    "fix-phase39b-sql-editor-admin.sql",
    "fix-phase40-meal-planner-picker.sql",
    "fix-phase41-browse-pagination.sql",
    "fix-phase42-scale-mitigation.sql",
    "fix-library-governed-links.sql",
    "fix-phase43-starter-library-health.sql",
    "fix-phase44-library-profiles.sql",
    "fix-phase45-site-fill.sql",
    "fix-phase46-library-profiles.sql",
    "fix-phase47-library-profiles.sql",
    "fix-phase48-recipe-ingredient-orphans.sql",
    "fix-phase49-library-profiles.sql",
    "fix-phase50-ingredient-categories.sql",
    "fix-phase51-soft-launch-pages.sql",
    "fix-phase52-library-profiles.sql",
    "fix-phase52-lane2-recipes.sql",
    "fix-phase52-recipe-orphan-repair.sql",
    "fix-phase53-print-fulfillment.sql",
    "fix-phase54-import-payload-refresh.sql",
    "fix-phase54-garden-kitchen-profiles.sql",
    "fix-phase55-garden-pages.sql",
    "fix-phase56-garden-excel-profiles.sql",
    "fix-phase57-garden-artichoke-profile.sql",
    "fix-phase57-garden-guilds-media.sql",
    "fix-phase58-garden-climate-copy.sql",
    "fix-phase59-garden-cultivar-climate-copy.sql",
    "schedule-dead-link-cron.sql",
    "schedule-email-cron.sql",
    "schedule-rotw-expiry-cron.sql",
}
KEEP.update(f"fix-phase59-garden-import-queue-payloads-{i:02d}.sql" for i in range(1, 15))

DELETE = {
    "fix-batch-ingest-grants.sql",  # subset of fix-recipe-batch-ingest.sql
    "fix-all-live.sql",
    "RUN-IN-SUPABASE-copy-paste-this.sql",
    "00-drop-functions.sql",
    "deactivate_account.sql",
}


def dest_for(name: str) -> Path:
    if name.startswith("garden-v") or name.startswith("fix-garden-"):
        return GARDEN
    if name.startswith("_bundle") or (name.endswith(".py") and name != "_cleanup_sql.py"):
        return DEV
    if name in DELETE:
        return None
    if name.startswith("fix-phase") and name not in KEEP:
        return HIST
    if name.startswith("fix-") and name not in KEEP:
        return HIST
    return HIST


def main() -> None:
    for sub in (HIST, GARDEN, GENERATED, DEV):
        sub.mkdir(parents=True, exist_ok=True)

    moved = deleted = 0
    for path in sorted(SQL.iterdir()):
        if not path.is_file():
            continue
        name = path.name
        if name in KEEP or name == "archive":
            continue
        if name in DELETE:
            path.unlink()
            deleted += 1
            print(f"DELETED {name}")
            continue
        if name in {"README.txt"}:
            continue
        target_dir = dest_for(name)
        if target_dir is None:
            continue
        target = target_dir / name
        if target.exists():
            path.unlink()
            deleted += 1
            print(f"DELETED duplicate {name}")
        else:
            shutil.move(str(path), str(target))
            moved += 1
            print(f"ARCHIVED {name} -> {target.relative_to(SQL)}")

    print(f"\nDone. kept={len(KEEP)} moved={moved} deleted={deleted}")


if __name__ == "__main__":
    main()
