#!/usr/bin/env python3
"""Download audio from Instagram recipe links and translate speech to English via Groq Whisper."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

import yt_dlp
from groq import Groq

ENGINES_DIR = Path(__file__).resolve().parent
BASE_DIR = ENGINES_DIR.parent
OUTPUT_DIR = BASE_DIR / "MyCookbook" / "reels"
FAILURES_LOG = OUTPUT_DIR / "_failures.jsonl"
PROGRESS_LOG = OUTPUT_DIR / "_progress.jsonl"
PROCESSED_REGISTRY = OUTPUT_DIR / "processed_recipes.json"
DEFAULT_COLLECTIONS_FILE = BASE_DIR / "inputs" / "instagram" / "saved_reels" / "saved_collections.json"
FALLBACK_COLLECTIONS_FILE = BASE_DIR / "inputs" / "instagram" / "saved_collections.json"
LEGACY_COLLECTIONS_FILE = BASE_DIR / "saved_collections.json"
WHISPER_MODEL = "whisper-large-v3"


def resolve_collections_file(explicit: Path | None) -> Path:
    if explicit is not None:
        path = explicit.expanduser().resolve()
        if not path.is_file():
            raise FileNotFoundError(f"Collections file not found: {path}")
        return path
    if DEFAULT_COLLECTIONS_FILE.is_file():
        return DEFAULT_COLLECTIONS_FILE
    if FALLBACK_COLLECTIONS_FILE.is_file():
        return FALLBACK_COLLECTIONS_FILE
    if LEGACY_COLLECTIONS_FILE.is_file():
        return LEGACY_COLLECTIONS_FILE
    raise FileNotFoundError(
        "Could not find saved_collections.json in RecipeExtraction/inputs/instagram/saved_reels/ "
        "(or a legacy location)."
    )


def extract_label_value(node: dict, label: str) -> str | None:
    if node.get("label") == label:
        value = node.get("value")
        return str(value).strip() if value else None
    return None


def walk_for_urls(node: object, urls: list[str], captions: dict[str, str]) -> None:
    if isinstance(node, dict):
        url = extract_label_value(node, "URL")
        if url and "instagram.com" in url:
            urls.append(url)
            caption = extract_label_value(node, "Caption")
            if caption:
                captions[url] = caption
        for value in node.values():
            walk_for_urls(value, urls, captions)
    elif isinstance(node, list):
        for item in node:
            walk_for_urls(item, urls, captions)


def load_recipes_collection(path: Path, collection_name: str = "Recipes") -> list[dict[str, str]]:
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)

    for collection in data:
        label_values = collection.get("label_values", [])
        name = next(
            (item.get("value") for item in label_values if item.get("label") == "Name"),
            None,
        )
        if name != collection_name:
            continue

        urls: list[str] = []
        captions: dict[str, str] = {}
        for item in label_values:
            walk_for_urls(item, urls, captions)

        seen: set[str] = set()
        entries: list[dict[str, str]] = []
        for url in urls:
            if url in seen:
                continue
            seen.add(url)
            entries.append({"url": url, "caption": captions.get(url, "")})
        return entries

    raise ValueError(f"Collection named '{collection_name}' was not found in {path}")


def reel_id_from_url(url: str) -> str:
    match = re.search(r"/(?:reel|p|tv)/([^/?#]+)", url)
    if match:
        return match.group(1)
    return re.sub(r"[^\w.-]+", "_", url.strip("/"))[:80] or "recipe"


def log_jsonl(path: Path, record: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def load_processed_registry() -> tuple[list[str], set[str]]:
    """Load the offline URL ledger; return ordered list and a lookup set."""
    if not PROCESSED_REGISTRY.is_file():
        return [], set()
    with PROCESSED_REGISTRY.open(encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"{PROCESSED_REGISTRY.name} must contain a JSON array of URLs.")
    urls = [str(url) for url in data]
    return urls, set(urls)


def save_processed_registry(urls: list[str]) -> None:
    with PROCESSED_REGISTRY.open("w", encoding="utf-8") as handle:
        json.dump(urls, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def mark_url_processed(registry: list[str], processed_urls: set[str], url: str) -> None:
    if url in processed_urls:
        return
    registry.append(url)
    processed_urls.add(url)
    save_processed_registry(registry)


def download_audio(url: str, temp_dir: Path, retries: int = 2) -> Path:
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            return _download_audio_once(url, temp_dir)
        except Exception as exc:  # noqa: BLE001 — retry transient download failures
            last_error = exc
            if attempt < retries:
                time.sleep(2 ** attempt)
    raise last_error or RuntimeError(f"Download failed for {url}")


def _download_audio_once(url: str, temp_dir: Path) -> Path:
    output_template = str(temp_dir / "%(id)s.%(ext)s")
    ydl_opts = {
        "format": "bestaudio/best",
        "outtmpl": output_template,
        "noplaylist": True,
        "quiet": True,
        "no_warnings": True,
        "http_headers": {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        },
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        if info is None:
            raise RuntimeError(f"yt-dlp returned no metadata for {url}")
        downloaded = Path(ydl.prepare_filename(info))
        if downloaded.exists():
            return downloaded
        for candidate in temp_dir.glob(f"{info.get('id', '*')}.*"):
            if candidate.is_file():
                return candidate
    raise FileNotFoundError(f"Download finished but audio file was not found for {url}")


def translate_audio(client: Groq, audio_path: Path, retries: int = 2) -> str:
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            with audio_path.open("rb") as audio_file:
                result = client.audio.translations.create(
                    model=WHISPER_MODEL,
                    file=audio_file,
                    response_format="text",
                    temperature=0.0,
                )
            text = getattr(result, "text", result)
            return str(text).strip()
        except Exception as exc:  # noqa: BLE001 — retry Groq rate limits / transient errors
            last_error = exc
            if attempt < retries:
                time.sleep(2 ** attempt)
    raise last_error or RuntimeError("Groq translation failed")


def write_markdown(output_path: Path, url: str, caption: str, translation: str) -> None:
    lines = [
        f"# Recipe — {reel_id_from_url(url)}",
        "",
        f"**Source:** {url}",
    ]
    if caption:
        lines.extend(["", "## Caption", "", caption])
    lines.extend(["", "## English Translation", "", translation, ""])
    output_path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract and translate recipe audio from the Instagram Recipes collection."
    )
    parser.add_argument(
        "--collections-file",
        type=Path,
        default=None,
        help="Path to saved_collections.json (defaults to repo root, then RecipeExtraction).",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Process only the first N links (useful for test batches).",
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        help="Skip links whose markdown file already exists in MyCookbook.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        print("Error: set the GROQ_API_KEY environment variable before running this script.", file=sys.stderr)
        return 1

    collections_file = resolve_collections_file(args.collections_file)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    try:
        entries = load_recipes_collection(collections_file)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Error loading collection: {exc}", file=sys.stderr)
        return 1

    try:
        processed_registry, processed_urls = load_processed_registry()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Error loading processed recipe registry: {exc}", file=sys.stderr)
        return 1

    if args.limit is not None:
        entries = entries[: max(args.limit, 0)]

    if not entries:
        print("No recipe links found to process.")
        return 0

    pending = [
        entry
        for entry in entries
        if entry["url"] not in processed_urls
        and not (args.skip_existing and (OUTPUT_DIR / f"{reel_id_from_url(entry['url'])}.md").exists())
    ]
    skipped_existing = sum(
        1
        for entry in entries
        if entry["url"] not in processed_urls
        and args.skip_existing
        and (OUTPUT_DIR / f"{reel_id_from_url(entry['url'])}.md").exists()
    )
    skipped_registry = sum(1 for entry in entries if entry["url"] in processed_urls)

    client = Groq(api_key=api_key)
    processed = 0
    failures = 0

    print(f"Loaded {len(entries)} link(s) from '{collections_file.name}'.")
    print(f"Loaded {len(processed_urls)} previously processed URL(s) from '{PROCESSED_REGISTRY.name}'.")
    if skipped_registry:
        print(f"Skipping {skipped_registry} URL(s) already recorded in the registry.")
    if args.skip_existing and skipped_existing:
        print(f"Skipping {skipped_existing} already extracted file(s).")
    print(f"Remaining to process: {len(pending)}")
    print(f"Writing markdown files to: {OUTPUT_DIR}")

    for index, entry in enumerate(entries, start=1):
        url = entry["url"]
        caption = entry["caption"]
        reel_id = reel_id_from_url(url)
        output_path = OUTPUT_DIR / f"{reel_id}.md"

        if url in processed_urls:
            print(f"[SKIPPING] URL already extracted previously: {url}")
            continue

        if args.skip_existing and output_path.exists():
            continue

        print(f"[{index}/{len(entries)}] Processing {url}")

        with tempfile.TemporaryDirectory(prefix="recipe-audio-") as temp_name:
            temp_dir = Path(temp_name)
            try:
                audio_path = download_audio(url, temp_dir)
                translation = translate_audio(client, audio_path)
                write_markdown(output_path, url, caption, translation)
                mark_url_processed(processed_registry, processed_urls, url)
                processed += 1
                log_jsonl(
                    PROGRESS_LOG,
                    {
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "reel_id": reel_id,
                        "url": url,
                        "status": "ok",
                    },
                )
                print(f"  Saved {output_path.name}")
            except Exception as exc:  # noqa: BLE001 — report and continue batch
                failures += 1
                log_jsonl(
                    FAILURES_LOG,
                    {
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "reel_id": reel_id,
                        "url": url,
                        "error": str(exc),
                    },
                )
                print(f"  Failed: {exc}", file=sys.stderr)

    skipped_total = skipped_registry + skipped_existing
    print(
        f"Done. Created {processed} file(s); {failures} failure(s); "
        f"{skipped_total} skipped ({skipped_registry} registry, {skipped_existing} existing file)."
    )
    if failures:
        print(f"Failure log: {FAILURES_LOG}")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
