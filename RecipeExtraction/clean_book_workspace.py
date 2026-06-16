#!/usr/bin/env python3
"""Remove local book extraction data not matching PDFs in inputs/books/."""

from __future__ import annotations

import json
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from processed_registry import load_registry, save_registry  # noqa: E402
from tcj_from_text import slugify  # noqa: E402

BOOKS_INPUT = BASE_DIR / "inputs" / "books"
BOOKS_OUTPUT = BASE_DIR / "MyCookbook" / "books"
BOOK_EXTENSIONS = {".pdf", ".docx", ".txt", ".md", ".text"}


def _safe_console(text: str) -> str:
    return (text or "").encode("ascii", "replace").decode("ascii")


def active_book_names() -> set[str]:
    if not BOOKS_INPUT.is_dir():
        return set()
    return {
        path.name
        for path in BOOKS_INPUT.iterdir()
        if path.is_file() and path.suffix.lower() in BOOK_EXTENSIONS
    }


def active_book_prefixes() -> set[str]:
    return {slugify(Path(name).stem) for name in active_book_names()}


def belongs_to_active_book(stem: str, prefixes: set[str]) -> bool:
    return any(stem == prefix or stem.startswith(f"{prefix}-") for prefix in prefixes)


def clean_json_files(prefixes: set[str]) -> int:
    if not BOOKS_OUTPUT.is_dir():
        return 0
    removed = 0
    for path in BOOKS_OUTPUT.glob("*.json"):
        if path.name.startswith("_"):
            continue
        if not belongs_to_active_book(path.stem, prefixes):
            path.unlink(missing_ok=True)
            removed += 1
            print(f"  removed JSON: {_safe_console(path.name)}")
    return removed


def clean_sidecar_logs(prefixes: set[str]) -> int:
    removed = 0
    for name in ("_ingested.jsonl", "_ingest_failures.jsonl"):
        path = BOOKS_OUTPUT / name
        if not path.is_file():
            continue
        kept: list[str] = []
        for line in path.read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                kept.append(line)
                continue
            slug = str(record.get("slug") or record.get("file") or "")
            if not slug or belongs_to_active_book(Path(slug).stem, prefixes):
                kept.append(line)
            else:
                removed += 1
        path.write_text("\n".join(kept) + ("\n" if kept else ""), encoding="utf-8")
    return removed


def clean_registry(active_names: set[str]) -> int:
    registry = load_registry()
    files = registry.get("processed_files", [])
    kept = []
    removed = 0
    for key in files:
        if not key.startswith("books:"):
            kept.append(key)
            continue
        book_name = key.split(":", 2)[1] if key.count(":") >= 2 else ""
        if book_name in active_names:
            kept.append(key)
        else:
            removed += 1
            print(f"  removed registry: {book_name}")
    registry["processed_files"] = kept
    save_registry(registry)
    return removed


def main() -> int:
    active_names = active_book_names()
    prefixes = active_book_prefixes()
    if not active_names:
        print("No book files in inputs/books/ — nothing to keep.")
        return 1

    print("Keeping books in inputs/books/:")
    for name in sorted(active_names):
        print(f"  • {name}")

    print("\nCleaning MyCookbook/books/ …")
    json_removed = clean_json_files(prefixes)
    log_removed = clean_sidecar_logs(prefixes)
    registry_removed = clean_registry(active_names)

    print(
        f"\nDone. removed_json={json_removed} "
        f"removed_log_rows={log_removed} removed_registry={registry_removed}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
