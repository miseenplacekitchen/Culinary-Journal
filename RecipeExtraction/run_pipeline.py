#!/usr/bin/env python3
"""
Live working ground — run all enabled recipe sources (extract + ingest).

Usage:
  python run_pipeline.py                    # all enabled sources
  python run_pipeline.py --source websites  # one source only
  python run_pipeline.py --extract-only     # skip Supabase ingest
  python run_pipeline.py --ingest-only      # upload only
  python run_pipeline.py --limit 5          # pass --limit to child scripts
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
CONFIG_FILE = BASE_DIR / "pipeline_config.json"

SOURCE_KEYS = {
    "websites": "websites",
    "website": "websites",
    "instagram_reels": "instagram_reels",
    "reels": "instagram_reels",
    "instagram": "instagram_reels",
    "instagram_profiles": "instagram_profiles",
    "youtube": "youtube",
    "videos": "videos",
    "books": "books",
    "word": "word_cookbook",
    "word_cookbook": "word_cookbook",
}


def load_config() -> dict:
    return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))


def ensure_layout() -> None:
    from input_paths import ensure_input_layout

    ensure_input_layout()
    for folder in (
        "engines",
        "MyCookbook/websites",
        "MyCookbook/books",
        "MyCookbook/word",
        "MyCookbook/youtube",
        "MyCookbook/videos",
        "MyCookbook/instagram",
        "MyCookbook/reels",
    ):
        (BASE_DIR / folder).mkdir(parents=True, exist_ok=True)


def run_step(label: str, cmd: list[str], extra_env: dict | None = None) -> int:
    print(f"\n{'=' * 60}\n[{label}]\n{'=' * 60}")
    print(" ", " ".join(cmd))
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    result = subprocess.run(cmd, cwd=str(BASE_DIR), env=env)
    return result.returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="TCJ 7-source recipe pipeline")
    parser.add_argument("--source", action="append", help="Run one source (websites, reels, youtube, …)")
    parser.add_argument("--extract-only", action="store_true")
    parser.add_argument("--ingest-only", action="store_true")
    parser.add_argument("--no-polish", action="store_true", help="Skip Groq polish step at end")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    ensure_layout()
    config = load_config()
    sources = config.get("sources", {})

    selected = list(sources.keys())
    if args.source:
        selected = []
        for raw in args.source:
            key = SOURCE_KEYS.get(raw.lower().strip())
            if not key or key not in sources:
                print(f"Unknown source: {raw}", file=sys.stderr)
                print("Valid:", ", ".join(sorted(set(SOURCE_KEYS.values()))), file=sys.stderr)
                return 1
            if key not in selected:
                selected.append(key)

    limit_args = ["--limit", str(args.limit)] if args.limit else []
    failures = 0

    print("TCJ Recipe Pipeline — live working ground")
    print("Enabled sources will extract new items only (central registry dedup).")
    print("Output -> MyCookbook/ -> Supabase submitted_recipes -> your website\n")

    for key in selected:
        meta = sources[key]
        if not meta.get("enabled"):
            print(f"[SKIP] {key} — disabled in pipeline_config.json (set enabled: true when ready)")
            continue

        label = meta.get("label", key)
        extract_script = meta.get("extract")
        ingest_script = meta.get("ingest")

        if not args.ingest_only and extract_script:
            script_path = BASE_DIR / extract_script
            if not script_path.is_file():
                print(f"[MISSING] {label}: {extract_script}")
                failures += 1
                continue
            cmd = [sys.executable, str(script_path), *limit_args]
            if key == "websites" and args.limit:
                pass  # websites supports --limit globally; --seed optional manually
            code = run_step(f"EXTRACT — {label}", cmd)
            if code != 0:
                failures += 1

        if not args.extract_only and ingest_script:
            script_path = BASE_DIR / ingest_script
            if not script_path.is_file():
                print(f"[MISSING] {label} ingest: {ingest_script}")
                failures += 1
                continue
            cmd = [sys.executable, str(script_path), *limit_args]
            ingest_subdir = meta.get("ingest_subdir")
            if ingest_script.endswith("ingest_tcj.py") and ingest_subdir:
                cmd.extend(["--subdir", str(ingest_subdir)])
            if ingest_script.endswith("ingest_instagram_reels.py"):
                cmd.extend(["--skip-ingested", "--skip-duplicates"])
            cwd = script_path.parent if script_path.parent != BASE_DIR else BASE_DIR
            print(f"\n{'=' * 60}\n[INGEST — {label}]\n{'=' * 60}")
            print(" ", " ".join(cmd))
            env = os.environ.copy()
            code = subprocess.run(cmd, cwd=str(cwd), env=env).returncode
            if code != 0:
                failures += 1
            continue

    if not args.extract_only and not args.ingest_only and not args.no_polish:
        polish_cmd = [sys.executable, str(BASE_DIR / "polish_pending.py"), "--all-pending"]
        if args.limit:
            polish_cmd.extend(["--limit", str(args.limit)])
        code = run_step("POLISH — Groq cleanup (all pending imports)", polish_cmd)
        if code != 0:
            print("Polish incomplete — re-run: python admin_routine.py", file=sys.stderr)
            failures += code

        summary_cmd = [sys.executable, str(BASE_DIR / "admin_routine.py"), "--skip-polish"]
        run_step("INBOX SUMMARY", summary_cmd)

    print(f"\nPipeline pass complete. failures={failures}")
    if failures:
        print("Fix errors above, then re-run — already-processed items are skipped automatically.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
