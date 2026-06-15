"""Local website source registry — mirrors recipe_website_sources for offline extract."""

from __future__ import annotations

import json
import re
from pathlib import Path
from urllib.parse import urlparse

from input_paths import URLS_WEBSITES

BASE_DIR = Path(__file__).resolve().parent
SOURCES_FILE = BASE_DIR / "website_sources.json"
URLS_FILE = URLS_WEBSITES

DEFAULT_SOURCES: dict[str, dict[str, str | bool]] = {
    "10.com.au": {"display_name": "10 MasterChef Recipes", "chef_name": "MasterChef Australia", "base_url": "https://10.com.au/masterchef/recipes"},
    "curryworld.me": {"display_name": "Veena's Curry World", "chef_name": "Veena", "base_url": "https://curryworld.me"},
    "malayali.me": {"display_name": "Malayali.me", "chef_name": "Malayali.me", "base_url": "https://malayali.me/"},
    "mariasmenu.com": {"display_name": "Maria's Menu", "chef_name": "Maria", "base_url": "https://mariasmenu.com/"},
    "poulef.com": {"display_name": "Poulef", "chef_name": "Poulef", "base_url": "https://poulef.com/"},
    "sandhyahariharan.co.uk": {"display_name": "Sandhya Hariharan", "chef_name": "Sandhya Hariharan", "base_url": "https://sandhyahariharan.co.uk/"},
    "thewanderlustkitchen.com": {"display_name": "The Wanderlust Kitchen", "chef_name": "The Wanderlust Kitchen", "base_url": "https://thewanderlustkitchen.com/"},
    "villagecookingkerala.com": {"display_name": "Village Cooking Kerala", "chef_name": "Village Cooking Kerala", "base_url": "https://villagecookingkerala.com/"},
    "allrecipes.com": {"display_name": "Allrecipes", "chef_name": "Allrecipes", "base_url": "https://www.allrecipes.com/"},
    "kevinandamanda.com": {"display_name": "Kevin & Amanda", "chef_name": "Kevin & Amanda", "base_url": "https://www.kevinandamanda.com/all-recipes/"},
    "kothiyavunu.com": {"display_name": "Kothiyavunu", "chef_name": "Shnunni", "base_url": "https://www.kothiyavunu.com/"},
    "philly.com.au": {"display_name": "Philly Australia", "chef_name": "Philly", "base_url": "https://www.philly.com.au/"},
    "taste.com.au": {"display_name": "Taste.com.au", "chef_name": "Taste", "base_url": "https://www.taste.com.au/"},
    "vegrecipesofindia.com": {"display_name": "Veg Recipes of India", "chef_name": "Dassana", "base_url": "https://www.vegrecipesofindia.com/"},
    "yummyntasty.com": {"display_name": "Yummy N Tasty", "chef_name": "Yummy N Tasty", "base_url": "https://www.yummyntasty.com/"},
    "yummytummyaarthi.com": {"display_name": "Yummy Tummy Aarthi", "chef_name": "Aarthi", "base_url": "https://www.yummytummyaarthi.com/"},
    "woolworths.com.au": {"display_name": "Woolworths Recipes", "chef_name": "Woolworths", "base_url": "https://www.woolworths.com.au/shop/recipes"},
    "coles.com.au": {"display_name": "Coles Recipes", "chef_name": "Coles", "base_url": "https://www.coles.com.au/recipes-inspiration"},
}


def normalize_host(url_or_host: str) -> str:
    text = (url_or_host or "").strip()
    if not text:
        return ""
    if "://" in text:
        text = urlparse(text).netloc or text
    text = text.lower().strip("/")
    if text.startswith("www."):
        text = text[4:]
    return text


def bootstrap_sources_file() -> dict[str, dict]:
    sources: dict[str, dict] = {}
    order = 0
    if URLS_FILE.is_file():
        for line in URLS_FILE.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            host = normalize_host(line)
            if not host:
                continue
            order += 1
            defaults = DEFAULT_SOURCES.get(host, {})
            sources[host] = {
                "display_name": str(defaults.get("display_name") or host),
                "chef_name": str(defaults.get("chef_name") or defaults.get("display_name") or host),
                "base_url": str(defaults.get("base_url") or line),
                "is_active": True,
                "sort_order": order,
            }
    if not sources:
        for host, meta in DEFAULT_SOURCES.items():
            sources[host] = {
                "display_name": str(meta["display_name"]),
                "chef_name": str(meta["chef_name"]),
                "base_url": str(meta["base_url"]),
                "is_active": True,
                "sort_order": len(sources) + 1,
            }
    SOURCES_FILE.write_text(json.dumps(sources, indent=2), encoding="utf-8")
    return sources


def load_sources() -> dict[str, dict]:
    if not SOURCES_FILE.is_file():
        return bootstrap_sources_file()
    try:
        data = json.loads(SOURCES_FILE.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            return data
    except json.JSONDecodeError:
        pass
    return bootstrap_sources_file()


def get_source_for_url(url: str) -> dict | None:
    host = normalize_host(url)
    sources = load_sources()
    return sources.get(host)


def is_source_active(url_or_host: str) -> bool:
    host = normalize_host(url_or_host)
    source = load_sources().get(host)
    if not source:
        return True
    return bool(source.get("is_active", True))


def chef_name_for_url(url: str, extracted_author: str = "") -> str:
    if extracted_author and extracted_author.strip():
        return extracted_author.strip()
    source = get_source_for_url(url)
    if source:
        chef = str(source.get("chef_name") or "").strip()
        if chef:
            return chef
    return ""


def display_name_for_url(url: str) -> str:
    source = get_source_for_url(url)
    if source:
        return str(source.get("display_name") or normalize_host(url))
    return normalize_host(url)
