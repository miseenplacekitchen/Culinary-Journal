#!/usr/bin/env python3
"""Project-wide cleanup tiers A+B+C — recipes first, garden deferred."""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
GARDEN_OFF = ROOT.parent / "Culinary-Journal-Garden-Reference"
SCRIPTS_ARCH = ROOT / "scripts" / "archive"
SQL = ROOT / "database" / "sql"
SQL_ARCH = SQL / "archive" / "historical-phases"

KEEP_PHASE_AT_ROOT = {
    "fix-recipe-batch-ingest.sql",
    "fix-website-sources.sql",
    "fix-admin-inbox-counts.sql",
}


def rm(path: Path) -> None:
    if path.is_file():
        path.unlink()
        print(f"DELETED {path.relative_to(ROOT)}")
    elif path.is_dir():
        shutil.rmtree(path)
        print(f"DELETED {path.relative_to(ROOT)}/")


def move(src: Path, dst: Path) -> None:
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        if dst.is_dir():
            shutil.rmtree(dst)
        else:
            dst.unlink()
    shutil.move(str(src), str(dst))
    print(f"MOVED {src.relative_to(ROOT)} -> {dst}")


def tier_a() -> None:
    for name in (
        "_excel_probe.txt",
        "_excel_profile_tail.txt",
        "Master_Incomplete_Items_Legacy_Archive.txt",
        "docs/SQL-RUN-ORDER.md",
        "send-queued-emails.js",
    ):
        p = ROOT / name
        if p.is_file():
            rm(p)

    archive = ROOT / "RecipeExtraction" / "Archive"
    if archive.is_dir():
        rm(archive)

    empty = ROOT / "brainstorm-inbox" / "_extracted_tomato.txt"
    if empty.is_file() and empty.stat().st_size == 0:
        rm(empty)


def tier_b() -> None:
    inbox = ROOT / "brainstorm-inbox"
    if not inbox.is_dir():
        return

    GARDEN_OFF.mkdir(parents=True, exist_ok=True)
    dest = GARDEN_OFF / "brainstorm-inbox"
    dest.mkdir(parents=True, exist_ok=True)
    readme = GARDEN_OFF / "README.txt"
    if not readme.exists():
        readme.write_text(
            "Garden reference moved off the main TCJ repo (June 2026).\n"
            "Recipes are the priority. Copy back from brainstorm-inbox/ when garden resumes.\n",
            encoding="utf-8",
        )

    for name in list(inbox.iterdir()):
        if name.name in {"import-payloads", "README.txt"}:
            continue
        move(name, dest / name.name)


def tier_c() -> None:
    SCRIPTS_ARCH.mkdir(parents=True, exist_ok=True)
    for name in (
        "probe-garden-excel.py",
        "generate-tomato-variety-seed.py",
        "scan-garden-inbox-queue.py",
        "attach-garden-import-payloads.py",
        "generate-garden-import-payload-refresh.py",
    ):
        src = ROOT / "scripts" / name
        if src.is_file():
            move(src, SCRIPTS_ARCH / name)

    blf = ROOT / "database" / "build-live-fix.py"
    if blf.is_file():
        move(blf, SQL / "archive" / "dev-tools" / "build-live-fix.py")

    rlive = SQL / "README-LIVE.md"
    if rlive.is_file():
        move(rlive, SQL / "archive" / "README-LIVE.md")

    SQL_ARCH.mkdir(parents=True, exist_ok=True)
    for path in sorted(SQL.glob("fix-phase*.sql")):
        if path.name in KEEP_PHASE_AT_ROOT:
            continue
        dst = SQL_ARCH / path.name
        if not dst.exists():
            move(path, dst)

    pd = ROOT / "Product_Direction_Draft.txt"
    if pd.is_file():
        arch = ROOT / "docs" / "archive"
        arch.mkdir(parents=True, exist_ok=True)
        move(pd, arch / "Product_Direction_Draft.txt")


def write_guides() -> None:
    guide = ROOT / "PROJECT-GUIDE.txt"
    guide.write_text(
        """THE CULINARY JOURNAL — Betty's project guide (recipes first)
================================================================

PRIORITY: 10,000+ recipes — extract → polish → Admin approve → live site.
Garden work is PAUSED. Reference files moved to:
  ..\\Culinary-Journal-Garden-Reference\\  (sibling folder, outside git)

YOUR THREE COMMANDS (RecipeExtraction folder)
---------------------------------------------
  .\\run_books.bat           PDFs in inputs\\books\\
  .\\run_pipeline.bat        websites, Instagram, YouTube, videos, Word
  .\\run_admin_routine.bat   catch-up Groq polish + inbox summary

Then: Admin dashboard → Recipes → Pending → approve in batches.

WHERE TO READ
-------------
  RecipeExtraction\\ROUTINE.txt     full recipe workflow
  database\\WHATS-WHAT.md           SQL (only 3 files you run now)
  Project_Status_Ledger.txt         what's done on live Supabase

WHAT YOU IGNORE
---------------
  database\\sql\\archive\\           old SQL — do not run
  brainstorm-inbox\\import-payloads  garden JSON (for later)
  scripts\\archive\\                 one-time dev tools
  tests\\                            for developers only

SEAMLESS FLOW (every batch)
---------------------------
  1. Drop files in RecipeExtraction\\inputs\\
  2. run_books.bat OR run_pipeline.bat  (upload + auto-polish)
  3. run_admin_routine.bat if Groq limit hit
  4. Admin approve — never edit 10k recipes by hand in the form

""",
        encoding="utf-8",
    )
    print(f"WROTE {guide.relative_to(ROOT)}")

    inbox_readme = ROOT / "brainstorm-inbox" / "README.txt"
    inbox_readme.write_text(
        "Garden reference bulk moved off-repo. import-payloads/ kept for when garden resumes.\n"
        "Recipe work: see PROJECT-GUIDE.txt and RecipeExtraction/ROUTINE.txt\n",
        encoding="utf-8",
    )


def main() -> None:
    print("=== Tier A ===")
    tier_a()
    print("\n=== Tier B ===")
    tier_b()
    print("\n=== Tier C ===")
    tier_c()
    write_guides()
    print("\nDone.")


def update_gitignore_note() -> None:
    gi = ROOT / ".gitignore"
    if gi.is_file() and "RecipeExtraction/MyCookbook/" in gi.read_text(encoding="utf-8"):
        print("gitignore already has MyCookbook/")


if __name__ == "__main__":
    main()
