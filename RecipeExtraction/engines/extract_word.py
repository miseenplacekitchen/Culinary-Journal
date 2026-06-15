#!/usr/bin/env python3
"""Source 7 — Word cookbook in inputs/word_docs/ → MyCookbook/word/"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _document_io import BASE_DIR, extract_document_folder  # noqa: E402

INPUT_DIR = BASE_DIR / "inputs" / "word_docs"
OUTPUT_DIR = BASE_DIR / "MyCookbook" / "word"
EXTENSIONS = {".docx", ".txt", ".md"}


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract recipes from Word cookbook files.")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    print(f"[*] Word cookbook: drop .docx files in {INPUT_DIR}")
    count = extract_document_folder(
        input_dir=INPUT_DIR,
        output_dir=OUTPUT_DIR,
        source_key="word",
        source_label="Personal Word cookbook",
        import_path="word-batch",
        extensions=EXTENSIONS,
        limit=args.limit,
    )
    print(f"\nDone. Saved {count} recipe JSON file(s) -> MyCookbook/word/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
