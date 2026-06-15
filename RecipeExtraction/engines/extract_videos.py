#!/usr/bin/env python3
"""Source 5 — Local video files in inputs/videos/ → MyCookbook/videos/"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _media_extract import BASE_DIR, extract_local_videos  # noqa: E402

INPUT_DIR = BASE_DIR / "inputs" / "videos"
OUTPUT_DIR = BASE_DIR / "MyCookbook" / "videos"


def main() -> int:
    parser = argparse.ArgumentParser(description="Transcribe local cooking videos to TCJ JSON.")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    print(f"[*] Downloaded videos: drop files in {INPUT_DIR}")
    print("    Supported: .mp4 .mkv .mov .webm .m4v .mp3 .m4a .wav")
    print("    Requires GROQ_API_KEY")
    try:
        count = extract_local_videos(INPUT_DIR, OUTPUT_DIR, limit=args.limit)
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(f"\nDone. Saved {count} recipe JSON file(s) -> MyCookbook/videos/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
