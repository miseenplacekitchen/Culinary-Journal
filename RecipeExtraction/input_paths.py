"""Where Betty drops files — all user input lives under inputs/."""

from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
INPUTS_DIR = BASE_DIR / "inputs"
URLS_DIR = INPUTS_DIR / "urls"

URLS_WEBSITES = URLS_DIR / "websites.txt"
URLS_INSTAGRAM = URLS_DIR / "instagram.txt"
URLS_YOUTUBE = URLS_DIR / "youtube.txt"
SAVED_COLLECTIONS = INPUTS_DIR / "instagram" / "saved_reels" / "saved_collections.json"

# Legacy paths (auto-migrated on first run if new files missing)
LEGACY_URLS_WEBSITES = BASE_DIR / "urls_websites.txt"
LEGACY_URLS_INSTAGRAM = BASE_DIR / "urls_instagram.txt"
LEGACY_URLS_YOUTUBE = BASE_DIR / "urls_youtube.txt"
LEGACY_SAVED_COLLECTIONS = BASE_DIR / "saved_collections.json"
LEGACY_SAVED_COLLECTIONS_INSTAGRAM = INPUTS_DIR / "instagram" / "saved_collections.json"


def ensure_input_layout() -> None:
    for folder in (
        INPUTS_DIR / "books",
        INPUTS_DIR / "videos",
        INPUTS_DIR / "word_docs",
        URLS_DIR,
        INPUTS_DIR / "instagram" / "saved_reels",
    ):
        folder.mkdir(parents=True, exist_ok=True)

    _migrate_legacy(LEGACY_URLS_WEBSITES, URLS_WEBSITES)
    _migrate_legacy(LEGACY_URLS_INSTAGRAM, URLS_INSTAGRAM)
    _migrate_legacy(LEGACY_URLS_YOUTUBE, URLS_YOUTUBE)
    _migrate_legacy(LEGACY_SAVED_COLLECTIONS, SAVED_COLLECTIONS)
    _migrate_legacy(LEGACY_SAVED_COLLECTIONS_INSTAGRAM, SAVED_COLLECTIONS)

    seeds = {
        URLS_WEBSITES: (
            "# Website seeds (one URL per line)\n"
            "https://curryworld.me\n"
        ),
        URLS_INSTAGRAM: (
            "# Instagram reel/post URLs (one per line)\n"
            "# Example: https://www.instagram.com/reel/ABC123/\n"
        ),
        URLS_YOUTUBE: "# YouTube video or channel URLs (one per line)\n",
        INPUTS_DIR / "books" / "README.txt": "See ..\\README.txt for full instructions.\n",
        INPUTS_DIR / "videos" / "README.txt": "See ..\\README.txt for full instructions.\n",
        INPUTS_DIR / "word_docs" / "README.txt": "See ..\\README.txt for full instructions.\n",
        INPUTS_DIR / "instagram" / "saved_reels" / "README.txt": (
            "Instagram Saved Collection export goes here as saved_collections.json\n"
            "See ..\\..\\README.txt section 5 for export steps.\n"
        ),
    }
    for path, content in seeds.items():
        if not path.exists():
            path.write_text(content, encoding="utf-8")


def _migrate_legacy(old: Path, new: Path) -> None:
    if old.is_file() and not new.is_file():
        new.parent.mkdir(parents=True, exist_ok=True)
        old.replace(new)
