#!/usr/bin/env python3
"""Quick title-only fix for pending imports when Groq is unavailable."""

from __future__ import annotations

import argparse
import os
import sys

from supabase import create_client

from tcj_normalize import clean_recipe_title

GENERIC_INTRO = "Imported from Personal book collection."


def main() -> int:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        print("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
        return 1

    parser = argparse.ArgumentParser()
    parser.add_argument("--import-path", default="book-batch", help="Filter by import_path; use --all for any")
    parser.add_argument("--all", action="store_true", help="Fix titles on all pending recipes")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    sb = create_client(url, key)
    q = sb.table("submitted_recipes").select("id,recipe_name,procedure_rewritten").eq("status", "pending")
    if not args.all and args.import_path:
        q = q.eq("import_path", args.import_path)
    rows = q.execute().data or []

    updated = 0
    for row in rows:
        if row.get("procedure_rewritten"):
            continue
        old = row.get("recipe_name") or ""
        new = clean_recipe_title(old)
        if new == old:
            continue
        if args.dry_run:
            print(f"  {old!r} -> {new!r}")
        else:
            sb.table("submitted_recipes").update({"recipe_name": new}).eq("id", row["id"]).execute()
            print(f"Fixed: {new}")
        updated += 1

    print(f"Done. titles_updated={updated}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
