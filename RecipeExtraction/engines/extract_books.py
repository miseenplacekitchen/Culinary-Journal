#!/usr/bin/env python3
"""Source 1 — Books & PDFs in inputs/books/ → MyCookbook/books/"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _document_io import (  # noqa: E402
    BASE_DIR,
    extract_document_folder,
    file_registry_key,
    refresh_document_file,
)

INPUT_DIR = BASE_DIR / "inputs" / "books"
OUTPUT_DIR = BASE_DIR / "MyCookbook" / "books"
EXTENSIONS = {".pdf", ".txt", ".md", ".text", ".docx"}


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract recipes from book PDFs and text files.")
    parser.add_argument("--limit", type=int, default=None, help="Process at most N files.")
    parser.add_argument(
        "--refresh",
        metavar="FILENAME",
        help="Re-process one file (clears its saved JSON + registry entry). Example: --refresh \"60 Ways Rice - Marshall Cavendish.pdf\"",
    )
    args = parser.parse_args()

    if args.refresh:
        path = INPUT_DIR / args.refresh
        if not path.is_file():
            print(f"File not found: {path}")
            return 1
        removed = refresh_document_file(path, OUTPUT_DIR, source_key="books")
        print(f"[*] Cleared prior output for {path.name} ({removed} json file(s) removed)")

    print(f"[*] Books & PDFs: drop files in {INPUT_DIR}")
    print(f"    Supported: {', '.join(sorted(EXTENSIONS))}")
    count = extract_document_folder(
        input_dir=INPUT_DIR,
        output_dir=OUTPUT_DIR,
        source_key="books",
        source_label="Personal book collection",
        import_path="book-batch",
        extensions=EXTENSIONS,
        limit=args.limit,
    )
    print(f"\nDone. Saved {count} recipe JSON file(s) -> MyCookbook/books/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
