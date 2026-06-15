#!/usr/bin/env python3
"""Source 3 — Instagram post/reel URLs (inputs/urls/instagram.txt) → MyCookbook/instagram/"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from input_paths import URLS_INSTAGRAM  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _media_extract import (  # noqa: E402
    BASE_DIR,
    extract_url_list_to_json,
    instagram_id_from_url,
    read_url_list,
)

URLS_FILE = URLS_INSTAGRAM
OUTPUT_DIR = BASE_DIR / "MyCookbook" / "instagram"


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract recipes from Instagram post/reel URLs.")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    urls = read_url_list(URLS_FILE)
    print(f"[*] Instagram profiles/posts: add URLs to {URLS_FILE.name} ({len(urls)} queued)")
    print("    Paste individual reel/post URLs (not just profile homepages).")
    print("    Requires GROQ_API_KEY")
    if not urls:
        print("    No URLs yet — add one per line, then re-run.")
        return 0
    try:
        count = extract_url_list_to_json(
            urls,
            OUTPUT_DIR,
            source_label="Instagram",
            import_path="instagram-batch",
            id_from_url=instagram_id_from_url,
            limit=args.limit,
            use_captions_first=False,
        )
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(f"\nDone. Saved {count} recipe JSON file(s) -> MyCookbook/instagram/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
