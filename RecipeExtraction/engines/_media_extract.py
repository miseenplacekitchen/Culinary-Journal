"""Groq Whisper + yt-dlp helpers for URL and local video sources."""

from __future__ import annotations

import json
import os
import re
import sys
import tempfile
import time
from pathlib import Path

import yt_dlp
from groq import Groq

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

from processed_registry import (  # noqa: E402
    is_file_processed,
    is_url_processed,
    load_registry,
    mark_file_processed,
    mark_url_processed,
    save_registry,
)
from tcj_from_text import slugify, structure_text_to_envelope  # noqa: E402

WHISPER_MODEL = "whisper-large-v3"
VIDEO_EXTS = {".mp4", ".mkv", ".mov", ".webm", ".m4v", ".mp3", ".m4a", ".wav"}


def read_url_list(path: Path) -> list[str]:
    if not path.is_file():
        return []
    urls = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        urls.append(line)
    return urls


def youtube_id_from_url(url: str) -> str:
    patterns = [
        r"(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/)([\w-]{6,})",
        r"youtube\.com/embed/([\w-]{6,})",
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return slugify(url)[:40]


def instagram_id_from_url(url: str) -> str:
    match = re.search(r"instagram\.com/(?:reel|p|tv)/([^/?#]+)", url, re.I)
    if match:
        return match.group(1)
    return slugify(url)[:40]


def download_audio(url: str, temp_dir: Path, retries: int = 2) -> Path:
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            return _download_audio_once(url, temp_dir)
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            if attempt < retries:
                time.sleep(2**attempt)
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
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            )
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


def fetch_youtube_captions(url: str) -> tuple[str, str]:
    """Return (title, caption_text) if subtitles exist."""
    ydl_opts = {
        "skip_download": True,
        "quiet": True,
        "no_warnings": True,
        "writesubtitles": True,
        "writeautomaticsub": True,
        "subtitleslangs": ["en", "en-US", "en-GB"],
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        if not info:
            return "", ""
        title = str(info.get("title") or "").strip()
        subs = info.get("subtitles") or {}
        auto = info.get("automatic_captions") or {}
        for lang in ("en", "en-US", "en-GB"):
            tracks = subs.get(lang) or auto.get(lang)
            if not tracks:
                continue
            for track in tracks:
                if track.get("ext") == "json3" and track.get("url"):
                    import urllib.request

                    raw = urllib.request.urlopen(track["url"], timeout=30).read().decode("utf-8", errors="ignore")
                    lines = re.findall(r'"text"\s*:\s*"([^"]+)"', raw)
                    text = " ".join(lines).replace("\\n", " ").strip()
                    if len(text) > 80:
                        return title, text
        return title, ""


def whisper_file(client: Groq, media_path: Path, retries: int = 2) -> str:
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            with media_path.open("rb") as handle:
                result = client.audio.translations.create(
                    model=WHISPER_MODEL,
                    file=handle,
                    response_format="text",
                    temperature=0.0,
                )
            text = getattr(result, "text", result)
            return str(text).strip()
        except Exception as exc:  # noqa: BLE001
            last_error = exc
            if attempt < retries:
                time.sleep(2**attempt)
    raise last_error or RuntimeError("Groq translation failed")


def save_tcj_json(
    output_dir: Path,
    *,
    slug: str,
    text: str,
    source_id: str,
    source_label: str,
    credit_name: str,
    credit_url: str,
    import_path: str,
    title_hint: str = "",
) -> bool:
    output_dir.mkdir(parents=True, exist_ok=True)
    envelope = structure_text_to_envelope(
        text,
        source_id=source_id,
        source_label=source_label,
        credit_name=credit_name,
        credit_url=credit_url,
        import_path=import_path,
        title_hint=title_hint,
    )
    if not envelope.get("ok"):
        return False
    out_path = output_dir / f"{slug}.json"
    out_path.write_text(json.dumps(envelope, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"    [OK] {out_path.name} - {envelope['structured']['recipe_name']}")
    return True


def groq_client() -> Groq:
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        raise RuntimeError("Set GROQ_API_KEY for video / YouTube / Instagram URL extraction.")
    return Groq(api_key=api_key)


def extract_local_videos(
    input_dir: Path,
    output_dir: Path,
    *,
    import_path: str = "video-batch",
    limit: int | None = None,
) -> int:
    input_dir.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in input_dir.iterdir() if p.is_file() and p.suffix.lower() in VIDEO_EXTS)
    if limit:
        files = files[:limit]
    if not files:
        print(f"  No video files in {input_dir}")
        return 0

    client = groq_client()
    registry = load_registry()
    saved = 0
    for path in files:
        reg_key = f"videos:{path.name}:{path.stat().st_mtime_ns}:{path.stat().st_size}"
        if is_file_processed(registry, reg_key):
            print(f"  [SKIP] already processed: {path.name}")
            continue
        print(f"  [*] Transcribing {path.name}")
        try:
            text = whisper_file(client, path)
        except Exception as exc:
            print(f"  [!] Failed {path.name}: {exc}")
            continue
        if len(text) < 80:
            print(f"  [SKIP] transcript too short: {path.name}")
            continue
        source_id = f"tcj://videos/{path.stem}"
        slug = slugify(path.stem)
        ok = save_tcj_json(
            output_dir,
            slug=slug,
            text=text,
            source_id=source_id,
            source_label="Downloaded cooking video",
            credit_name=path.stem.replace("-", " ").replace("_", " "),
            credit_url=source_id,
            import_path=import_path,
            title_hint=path.stem.replace("-", " ").replace("_", " "),
        )
        if ok:
            mark_file_processed(registry, reg_key)
            save_registry(registry)
            saved += 1
    return saved


def extract_url_list_to_json(
    urls: list[str],
    output_dir: Path,
    *,
    source_label: str,
    import_path: str,
    id_from_url,
    limit: int | None = None,
    use_captions_first: bool = False,
) -> int:
    if limit:
        urls = urls[:limit]
    if not urls:
        return 0

    client = groq_client()
    registry = load_registry()
    saved = 0

    for index, url in enumerate(urls, 1):
        clean = url.rstrip("/")
        if is_url_processed(registry, clean):
            print(f"  [SKIP] already processed: {url}")
            continue
        media_id = id_from_url(url)
        print(f"  [{index}/{len(urls)}] {url}")

        title_hint = ""
        text = ""
        try:
            if use_captions_first:
                title_hint, text = fetch_youtube_captions(url)
            if len(text) < 80:
                with tempfile.TemporaryDirectory(prefix="tcj-audio-") as temp_name:
                    audio_path = download_audio(url, Path(temp_name))
                    text = whisper_file(client, audio_path)
        except Exception as exc:
            print(f"  [!] Failed: {exc}")
            continue

        if len(text) < 80:
            print("  [SKIP] transcript too short")
            continue

        slug = slugify(f"{media_id}-{title_hint or 'recipe'}")
        ok = save_tcj_json(
            output_dir,
            slug=slug,
            text=text,
            source_id=clean,
            source_label=source_label,
            credit_name=title_hint or source_label,
            credit_url=clean,
            import_path=import_path,
            title_hint=title_hint,
        )
        if ok:
            mark_url_processed(registry, clean)
            save_registry(registry)
            saved += 1
    return saved
