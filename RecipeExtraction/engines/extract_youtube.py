#!/usr/bin/env python3
"""Source 6 — YouTube channels/videos (inputs/urls/youtube.txt) → MyCookbook/youtube/"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from input_paths import URLS_YOUTUBE  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _media_extract import (  # noqa: E402
    BASE_DIR,
    extract_url_list_to_json,
    read_url_list,
    youtube_id_from_url,
)

URLS_FILE = URLS_YOUTUBE
OUTPUT_DIR = BASE_DIR / "MyCookbook" / "youtube"


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract recipes from YouTube URLs.")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    urls = read_url_list(URLS_FILE)
    print(f"[*] YouTube: add channel/video URLs to {URLS_FILE.name} ({len(urls)} queued)")
    print("    Requires GROQ_API_KEY (uses captions when available, else Whisper)")
    if not urls:
        print("    No URLs yet — add one per line, then re-run.")
        return 0
    try:
        count = extract_url_list_to_json(
            urls,
            OUTPUT_DIR,
            source_label="YouTube",
            import_path="youtube-batch",
            id_from_url=youtube_id_from_url,
            limit=args.limit,
            use_captions_first=True,
        )
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(f"\nDone. Saved {count} recipe JSON file(s) -> MyCookbook/youtube/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
