"""Central dedup ledger for all 7 recipe sources."""

from __future__ import annotations

import json
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
REGISTRY_FILE = BASE_DIR / "processed_registry.json"


def empty_registry() -> dict:
    return {
        "processed_urls": [],
        "processed_reel_ids": [],
        "processed_youtube_ids": [],
        "processed_files": [],
        "version": 2,
    }


def load_registry() -> dict:
    if not REGISTRY_FILE.is_file():
        return empty_registry()
    try:
        data = json.loads(REGISTRY_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return empty_registry()
    if isinstance(data, list):
        return {"processed_urls": data, "processed_reel_ids": [], "processed_youtube_ids": [], "processed_files": [], "version": 2}
    if isinstance(data, dict):
        base = empty_registry()
        base.update(data)
        for key in ("processed_urls", "processed_reel_ids", "processed_youtube_ids", "processed_files"):
            if not isinstance(base.get(key), list):
                base[key] = []
        return base
    return empty_registry()


def save_registry(registry: dict) -> None:
    REGISTRY_FILE.write_text(json.dumps(registry, indent=2), encoding="utf-8")


def is_url_processed(registry: dict, url: str) -> bool:
    clean = (url or "").rstrip("/")
    return clean in {u.rstrip("/") for u in registry.get("processed_urls", [])}


def mark_url_processed(registry: dict, url: str) -> None:
    clean = (url or "").rstrip("/")
    if not clean:
        return
    urls = registry.setdefault("processed_urls", [])
    if clean not in urls:
        urls.append(clean)


def is_reel_processed(registry: dict, reel_id: str) -> bool:
    return reel_id in set(registry.get("processed_reel_ids", []))


def mark_reel_processed(registry: dict, reel_id: str) -> None:
    if reel_id and reel_id not in registry.setdefault("processed_reel_ids", []):
        registry["processed_reel_ids"].append(reel_id)


def is_file_processed(registry: dict, file_key: str) -> bool:
    return file_key in set(registry.get("processed_files", []))


def mark_file_processed(registry: dict, file_key: str) -> None:
    if file_key and file_key not in registry.setdefault("processed_files", []):
        registry["processed_files"].append(file_key)
