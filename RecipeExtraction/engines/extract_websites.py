#!/usr/bin/env python3
"""
Discover recipe URLs from seeds in inputs/urls/websites.txt, extract via TCJ import logic
(Node: lib/recipe-import-* + recipe-batch-structure), save TCJ JSON under MyCookbook/websites/.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urljoin, urlparse

import requests

# Allow imports from RecipeExtraction root when run as engines/extract_websites.py
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from tcj_extract import fetch_and_structure_url  # noqa: E402
from input_paths import URLS_WEBSITES  # noqa: E402
from website_sources import bootstrap_sources_file, is_source_active, normalize_host  # noqa: E402

BASE_DIR = Path(__file__).resolve().parent.parent
URLS_FILE = URLS_WEBSITES
REGISTRY_FILE = BASE_DIR / "processed_registry.json"
DISCOVERED_CACHE = BASE_DIR / "discovered_urls.json"
OUTPUT_ROOT = BASE_DIR / "MyCookbook" / "websites"
NODE_SCRIPT = BASE_DIR / "scripts" / "url-to-tcj.mjs"
PROJECT_ROOT = BASE_DIR.parent

REQUEST_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (compatible; TheCulinaryJournalBot/1.0; +https://theculinaryjournal.site)"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}

NON_RECIPE_PATH = re.compile(
    r"/(?:category|categories|tag|tags|author|page|search|privacy|terms|about|contact|"
    r"menu-list|recipe-request|my-cooking-videos|useful-tips|wp-content|wp-admin|feed)\b",
    re.I,
)

SITEMAP_LOC_RE = re.compile(r"<loc>\s*(https?://[^<]+)\s*</loc>", re.I)


def load_registry() -> dict:
    if REGISTRY_FILE.is_file():
        try:
            data = json.loads(REGISTRY_FILE.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                data.setdefault("processed_urls", [])
                return data
        except json.JSONDecodeError:
            pass
    return {"processed_urls": []}


def save_registry(registry: dict) -> None:
    REGISTRY_FILE.write_text(json.dumps(registry, indent=2), encoding="utf-8")


def read_seeds() -> list[str]:
    if not URLS_FILE.is_file():
        return []
    seeds: list[str] = []
    for line in URLS_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        seeds.append(line)
    return seeds


def normalize_origin(seed: str) -> str:
    parsed = urlparse(seed.strip())
    if not parsed.scheme:
        parsed = urlparse("https://" + seed.strip())
    return f"{parsed.scheme}://{parsed.netloc}".rstrip("/")


def is_likely_recipe_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
    except ValueError:
        return False
    if parsed.scheme not in ("http", "https"):
        return False
    path = (parsed.path or "/").lower()
    if path in ("", "/"):
        return False
    if NON_RECIPE_PATH.search(path):
        return False
    if re.search(r"\.(jpg|jpeg|png|gif|webp|pdf|zip)$", path, re.I):
        return False
    if re.search(r"/\d{4}/\d{2}/\d{2}/", path):
        return True
    if re.search(r"/recipe[s]?/", path):
        return True
    host = parsed.netloc.lower()
    if host.endswith(("allrecipes.com", "taste.com.au", "coles.com.au", "woolworths.com.au", "10.com.au")):
        return bool(re.search(r"/recipe", path))
    return len(path.strip("/").split("/")) >= 2 and len(path) > 8


def fetch_text(url: str, timeout: int = 25) -> str | None:
    try:
        response = requests.get(url, headers=REQUEST_HEADERS, timeout=timeout)
        if response.status_code != 200:
            return None
        return response.text
    except requests.RequestException:
        return None


def extract_locs(xml_text: str) -> list[str]:
    return [m.group(1).strip() for m in SITEMAP_LOC_RE.finditer(xml_text or "")]


def discover_sitemap_urls(origin: str) -> list[str]:
    """Collect candidate recipe URLs from robots.txt + common sitemap paths."""
    found: set[str] = set()
    sitemap_queue: list[str] = []

    robots = fetch_text(urljoin(origin + "/", "robots.txt"))
    if robots:
        for line in robots.splitlines():
            if line.lower().startswith("sitemap:"):
                sm = line.split(":", 1)[1].strip()
                if sm.startswith("http"):
                    sitemap_queue.append(sm)

    for path in (
        "/wp-sitemap.xml",
        "/sitemap_index.xml",
        "/sitemap.xml",
        "/wp-sitemap-posts-post-1.xml",
    ):
        sitemap_queue.append(origin + path)

    seen_sitemaps: set[str] = set()
    while sitemap_queue:
        sm_url = sitemap_queue.pop(0)
        if sm_url in seen_sitemaps:
            continue
        seen_sitemaps.add(sm_url)

        xml = fetch_text(sm_url)
        if not xml:
            continue
        locs = extract_locs(xml)
        for loc in locs:
            if loc.endswith(".xml") or "/wp-sitemap-" in loc and loc.endswith(".xml"):
                if loc not in seen_sitemaps:
                    sitemap_queue.append(loc)
                continue
            if normalize_origin(loc) == origin and is_likely_recipe_url(loc):
                found.add(loc.rstrip("/"))

        time.sleep(0.3)

    return sorted(found)


def load_discovered_cache() -> dict[str, list[str]]:
    if DISCOVERED_CACHE.is_file():
        try:
            data = json.loads(DISCOVERED_CACHE.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                return {k: list(v) for k, v in data.items() if isinstance(v, list)}
        except json.JSONDecodeError:
            pass
    return {}


def save_discovered_cache(cache: dict[str, list[str]]) -> None:
    DISCOVERED_CACHE.write_text(json.dumps(cache, indent=2), encoding="utf-8")


def discover_urls_for_seed(seed: str, cache: dict[str, list[str]], refresh: bool = False) -> list[str]:
    origin = normalize_origin(seed)
    if not refresh and origin in cache and cache[origin]:
        print(f"\n[*] Using cached URLs for {origin} ({len(cache[origin])} links)")
        return cache[origin]

    print(f"\n[*] Discovering recipes for {origin} ...")
    urls = discover_sitemap_urls(origin)
    if urls:
        print(f"    Sitemap: {len(urls)} candidate URL(s)")
        cache[origin] = urls
        save_discovered_cache(cache)
        return urls

    if is_likely_recipe_url(seed):
        print("    Direct recipe URL seed")
        cache[origin] = [seed.rstrip("/")]
        save_discovered_cache(cache)
        return cache[origin]

    print("    No sitemap recipes found — add direct recipe URLs or try later")
    cache[origin] = []
    save_discovered_cache(cache)
    return []


def slug_for_url(url: str) -> str:
    path = urlparse(url).path.strip("/")
    slug = path.split("/")[-1] if path else "recipe"
    slug = re.sub(r"[^\w\-]+", "-", slug.lower()).strip("-")
    return slug or "recipe"


def host_folder(url: str) -> str:
    host = urlparse(url).netloc.lower()
    if host.startswith("www."):
        host = host[4:]
    return host


def run_extract(url: str) -> dict | None:
    """Prefer TCJ Node import logic when Node is installed; otherwise Python extractor."""
    node = shutil.which("node")
    if node and NODE_SCRIPT.is_file():
        try:
            proc = subprocess.run(
                [node, str(NODE_SCRIPT), url],
                cwd=str(PROJECT_ROOT),
                capture_output=True,
                text=True,
                timeout=120,
                check=False,
            )
            stdout = (proc.stdout or "").strip()
            if stdout:
                payload = json.loads(stdout)
                if payload.get("ok"):
                    return payload
        except (subprocess.TimeoutExpired, OSError, json.JSONDecodeError):
            pass

    try:
        return fetch_and_structure_url(url)
    except Exception as exc:  # noqa: BLE001
        print(f"    [!] Extract failed for {url}: {exc}")
        return None


def save_recipe(url: str, payload: dict) -> Path | None:
    structured = payload.get("structured") or {}
    host = host_folder(url)
    out_dir = OUTPUT_ROOT / host
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{slug_for_url(url)}.json"

    envelope = {
        "schema_version": payload.get("schema_version", "tcj-website-v1"),
        "source_url": url,
        "host": payload.get("host") or host,
        "extractor": payload.get("extractor"),
        "extractor_version": payload.get("extractor_version"),
        "parser_version": payload.get("parser_version"),
        "warnings": payload.get("warnings") or [],
        "import_quality": payload.get("import_quality") or {},
        "structured": structured,
        "paste_snapshot": payload.get("paste_snapshot") or "",
        "source_display_name": payload.get("source_display_name") or "",
    }
    out_path.write_text(json.dumps(envelope, indent=2, ensure_ascii=False), encoding="utf-8")
    return out_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Discover and extract website recipes.")
    parser.add_argument("--limit", type=int, default=None, help="Process at most N pending URLs.")
    parser.add_argument(
        "--seed",
        type=str,
        default=None,
        help="Only run one seed site, e.g. https://curryworld.me",
    )
    parser.add_argument(
        "--refresh-discovery",
        action="store_true",
        help="Re-fetch sitemaps instead of using discovered_urls.json cache.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    registry = load_registry()
    processed: set[str] = set(registry.get("processed_urls") or [])

    seeds = read_seeds()
    if args.seed:
        seeds = [s for s in seeds if normalize_origin(s) == normalize_origin(args.seed)] or [args.seed]

    if not seeds:
        print(f"No seeds in {URLS_FILE}")
        return 1

    bootstrap_sources_file()
    seeds = [s for s in seeds if is_source_active(s)]
    if not seeds:
        print("All website sources are switched OFF in website_sources.json / admin panel.")
        return 1

    discovered_cache = load_discovered_cache()
    all_urls: list[str] = []
    for seed in seeds:
        all_urls.extend(
            discover_urls_for_seed(seed, discovered_cache, refresh=args.refresh_discovery)
        )

    unique_urls = sorted(set(u.rstrip("/") for u in all_urls))
    pending = []
    for url in unique_urls:
        if url in processed:
            out_file = OUTPUT_ROOT / host_folder(url) / f"{slug_for_url(url)}.json"
            if out_file.is_file():
                continue
        pending.append(url)
    if args.limit:
        pending = pending[: args.limit]

    print(f"\n[*] Total discovered: {len(unique_urls)} | Already done: {len(processed)} | Pending: {len(pending)}")

    saved = 0
    skipped = 0
    failed = 0

    for idx, url in enumerate(pending, 1):
        print(f"[{idx}/{len(pending)}] {url}")
        payload = run_extract(url)
        if not payload:
            failed += 1
            time.sleep(1.0)
            continue

        if not payload.get("ok"):
            reason = payload.get("reason") or payload.get("error") or "quality gate"
            print(f"    [SKIP] {reason}")
            skipped += 1
            time.sleep(1.0)
            continue

        out_path = save_recipe(url, payload)
        if out_path:
            processed.add(url)
            registry["processed_urls"] = sorted(processed)
            save_registry(registry)
            structured = payload.get("structured") or {}
            ing = sum(len(s.get("items") or []) for s in structured.get("ingredients") or [])
            steps = sum(len(s.get("steps") or []) for s in structured.get("method") or [])
            print(f"    [OK] {out_path.name} ({ing} ingredients, {steps} steps)")
            saved += 1

        time.sleep(1.0)

    print(f"\nDone. saved={saved} skipped={skipped} failed={failed}")
    print(f"Output: {OUTPUT_ROOT}")
    print("Next: . .\\setup-env.ps1  then  python ingest_tcj.py --subdir websites --limit 1")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
