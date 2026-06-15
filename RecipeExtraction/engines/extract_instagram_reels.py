#!/usr/bin/env python3
"""Source 4 — Instagram Saved Collection reels → MyCookbook/reels/*.md"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from input_paths import SAVED_COLLECTIONS  # noqa: E402

BASE_DIR = Path(__file__).resolve().parent.parent
EXTRACT_SCRIPT = Path(__file__).resolve().parent / "instagram_reels_extract.py"
COLLECTIONS = SAVED_COLLECTIONS


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract Instagram saved reels to transcript markdown.")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    if not COLLECTIONS.is_file():
        print(f"Missing {COLLECTIONS}")
        print("Export your Instagram Saved Collection and save as:")
        print("  inputs/instagram/saved_reels/saved_collections.json")
        print("See inputs/README.txt section 5 for steps.")
        return 1
    if not EXTRACT_SCRIPT.is_file():
        print(f"Missing {EXTRACT_SCRIPT}")
        return 1

    cmd = [sys.executable, str(EXTRACT_SCRIPT), "--collections-file", str(COLLECTIONS), "--skip-existing"]
    if args.limit:
        cmd.extend(["--limit", str(args.limit)])

    print("[*] Instagram saved reels → MyCookbook/reels/*.md")
    print(f"[*] Using {COLLECTIONS.name}")
    return subprocess.call(cmd, cwd=str(BASE_DIR))


if __name__ == "__main__":
    raise SystemExit(main())
