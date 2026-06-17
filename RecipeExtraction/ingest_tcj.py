#!/usr/bin/env python3
"""
Upload TCJ JSON from MyCookbook/{subdir}/ into submitted_recipes.

Environment variables:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY
  TCJ_INGEST_USER_ID

Usage:
  python ingest_tcj.py --subdir websites --dry-run --limit 1
  python ingest_tcj.py --subdir books --limit 10
  python ingest_tcj.py --subdir all
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from supabase import Client, create_client

from tcj_ingest import build_submitted_recipes_row, normalize_host, normalize_structured
from tcj_normalize import clean_recipe_title
from tcj_from_text import slugify
from website_sources import is_source_active

BASE_DIR = Path(__file__).resolve().parent
MYCOOKBOOK = BASE_DIR / "MyCookbook"
BOOKS_INPUT_DIR = BASE_DIR / "inputs" / "books"
JSON_SUBDIRS = ("websites", "books", "word", "youtube", "videos", "instagram")
TRUSTED_BOOK_PARSERS = {"cookbook-serves-v1", "yield-cookbook-v1"}
COOKBOOK_SECTION = re.compile(
    r"\((?:Vegetarian|Seafood|Poultry|Meat|Desserts) section\)",
    re.I,
)


def is_trusted_book_envelope(envelope: dict) -> bool:
    """Only upload book JSON we are confident about — skips junk generic PDF splits."""
    if envelope.get("book_parser") in TRUSTED_BOOK_PARSERS:
        return True
    intro = (envelope.get("structured") or {}).get("introduction") or ""
    return bool(COOKBOOK_SECTION.search(intro))


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def source_already_ingested(supabase: Client, source_url: str) -> bool:
    if not source_url:
        return False
    result = (
        supabase.table("submitted_recipes")
        .select("id")
        .eq("import_source_url", source_url)
        .limit(1)
        .execute()
    )
    return bool(result.data)


def log_line(path: Path, record: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record) + "\n")


def active_book_prefixes() -> set[str]:
    if not BOOKS_INPUT_DIR.is_dir():
        return set()
    exts = {".pdf", ".docx", ".txt", ".md", ".text"}
    return {slugify(path.stem) for path in BOOKS_INPUT_DIR.iterdir() if path.is_file() and path.suffix.lower() in exts}


def belongs_to_active_book(path: Path, prefixes: set[str]) -> bool:
    if not prefixes:
        return True
    stem = path.stem
    return any(stem == prefix or stem.startswith(f"{prefix}-") for prefix in prefixes)


def resolve_files(subdir: str, limit: int | None) -> list[Path]:
    if subdir == "all":
        files: list[Path] = []
        for name in JSON_SUBDIRS:
            folder = MYCOOKBOOK / name
            if folder.is_dir():
                files.extend(sorted(folder.rglob("*.json")))
    else:
        folder = MYCOOKBOOK / subdir
        files = sorted(folder.rglob("*.json")) if folder.is_dir() else []
    files = [p for p in files if not p.name.startswith("_")]
    if subdir == "books":
        prefixes = active_book_prefixes()
        if prefixes:
            before = len(files)
            files = [p for p in files if belongs_to_active_book(p, prefixes)]
            dropped = before - len(files)
            if dropped:
                print(f"Ignoring {dropped} stale book JSON file(s) not matching inputs/books/")
    if limit:
        files = files[:limit]
    return files


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Ingest TCJ JSON batches into submitted_recipes.")
    parser.add_argument(
        "--subdir",
        default="websites",
        choices=[*JSON_SUBDIRS, "all"],
        help="Which MyCookbook folder to ingest (default: websites).",
    )
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument(
        "--until-ok",
        type=int,
        default=None,
        help="Process files in order; stop after this many successful ingests (one-at-a-time upload).",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--allow-duplicates", action="store_true")
    parser.add_argument(
        "--trusted-books-only",
        action="store_true",
        help="Books folder only: skip generic/unverified PDF extractions (recommended).",
    )
    parser.add_argument(
        "--all-books",
        action="store_true",
        help="Upload every book JSON, including unverified extractions (not recommended).",
    )
    return parser.parse_args()


def _configure_stdio_utf8() -> None:
    """Avoid false failures on Windows when recipe slugs contain Unicode (e.g. PDF ligatures)."""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if callable(reconfigure):
            try:
                reconfigure(encoding="utf-8", errors="replace")
            except (OSError, ValueError):
                pass


def main() -> int:
    args = parse_args()
    _configure_stdio_utf8()

    supabase_url = os.environ.get("SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    user_id = os.environ.get("TCJ_INGEST_USER_ID")

    if not args.dry_run and (not supabase_url or not service_key or not user_id):
        print("Set SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, TCJ_INGEST_USER_ID", file=sys.stderr)
        return 1

    files = resolve_files(args.subdir, args.limit if not args.until_ok else None)
    if not files:
        print(f"No JSON files under MyCookbook/{args.subdir}/")
        return 0

    trusted_books_only = args.trusted_books_only or (
        args.subdir == "books" and not args.all_books
    )

    supabase: Client | None = None if args.dry_run else create_client(supabase_url, service_key)
    log_dir = MYCOOKBOOK / (args.subdir if args.subdir != "all" else "batch")
    ingested_log = log_dir / "_ingested.jsonl"
    failures_log = log_dir / "_ingest_failures.jsonl"

    ok = failed = skipped = 0
    skip_dupes = not args.allow_duplicates
    print(
        f"Processing {len(files)} file(s) from MyCookbook/{args.subdir}"
        f"{' (dry-run)' if args.dry_run else ''}"
        f"{' [trusted books only]' if trusted_books_only and args.subdir in {'books', 'all'} else ''}..."
    )

    for path in files:
        slug = path.stem
        try:
            envelope = load_json(path)
            if trusted_books_only and "books" in path.parts and not is_trusted_book_envelope(envelope):
                skipped += 1
                continue
            source_url = (envelope.get("source_url") or "").strip()
            import_path = envelope.get("import_path") or "tcj-batch"
            is_website = "websites" in path.parts and source_url.startswith("http")

            if is_website and not is_source_active(source_url):
                host = normalize_host(source_url)
                print(f"Skip inactive website source {host}: {slug}")
                skipped += 1
                continue

            structured = normalize_structured(envelope.get("structured") or {})
            structured["recipe_name"] = clean_recipe_title(structured.get("recipe_name") or "")
            warnings = list(envelope.get("warnings") or [])

            if skip_dupes and supabase and source_url and source_already_ingested(supabase, source_url):
                print(f"Skip duplicate {slug}")
                skipped += 1
                continue

            row = build_submitted_recipes_row(
                structured,
                source_url=source_url,
                user_id=user_id or "",
                paste_snapshot=envelope.get("paste_snapshot") or "",
                extractor_version=envelope.get("extractor_version") or import_path,
                warnings=warnings,
                source_display_name=envelope.get("source_display_name") or envelope.get("host") or "",
                import_path=import_path,
            )

            if args.dry_run:
                preview = {
                    "file": str(path.relative_to(BASE_DIR)),
                    "recipe_name": row["recipe_name"],
                    "category": row["category"],
                    "source_url": source_url,
                    "import_path": import_path,
                }
                print(json.dumps(preview, indent=2))
                ok += 1
                if args.until_ok and ok >= args.until_ok:
                    break
                continue

            assert supabase is not None
            result = supabase.table("submitted_recipes").insert(row).execute()
            inserted_id = result.data[0]["id"] if result.data else None
            log_line(
                ingested_log,
                {
                    "file": str(path.relative_to(BASE_DIR)),
                    "id": inserted_id,
                    "recipe_name": row["recipe_name"],
                    "source_url": source_url,
                    "at": datetime.now(timezone.utc).isoformat(),
                },
            )
            print(f"Ingested {slug} -> {inserted_id} ({row['recipe_name']})")
            ok += 1
            if args.until_ok and ok >= args.until_ok:
                break
        except Exception as exc:  # noqa: BLE001
            failed += 1
            log_line(
                failures_log,
                {"file": str(path), "error": str(exc), "at": datetime.now(timezone.utc).isoformat()},
            )
            print(f"Failed {slug}: {exc}", file=sys.stderr)

    print(f"Done. ok={ok} failed={failed} skipped={skipped}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
