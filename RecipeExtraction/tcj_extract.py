"""Fetch a recipe URL and return TCJ-shaped JSON (no Groq, no Node required)."""

from __future__ import annotations

import html as html_lib
import json
import re
from typing import Any
from urllib.parse import urlparse

import requests

from tcj_ingest import TCJ_CATEGORIES, normalize_choice, normalize_structured
from website_sources import chef_name_for_url, display_name_for_url

REQUEST_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (compatible; TheCulinaryJournalBot/1.0; +https://theculinaryjournal.site)"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
}

NON_RECIPE_PATH = re.compile(
    r"/(?:category|categories|tag|tags|author|page|search|privacy|terms|about|contact|"
    r"menu-list|recipe-request|my-cooking-videos|useful-tips|wp-content|feed)\b",
    re.I,
)

JUNK_STEP = re.compile(
    r"^(?:print\s*\(|share this|leave a reply|recent posts|facebook|instagram|youtube|"
    r"food advertisements|related posts?|\d+\s+comments?|loading comments|veena$|vinu$|love$)",
    re.I,
)

ING_LINE = re.compile(
    r"^([\d\s/\.\u00bc-\u00be\-]+?)\s*"
    r"(tsp|teaspoon|teaspoons|tbsp|tablespoon|tablespoons|cup|cups|g|gm|gram|grams|kg|ml|"
    r"oz|lb|lbs|clove|cloves|nos|no|pinch|bunch|sprig|sprigs|slice|slices|piece|pieces)?\s*\.?\s+(.+)$",
    re.I,
)

CATEGORY_RULES = [
    (re.compile(r"\b(biriyani|biryani|pilaf|pulao|fried rice)\b", re.I), "Grains & Comfort"),
    (re.compile(r"\b(puttu|idiyappam|idli|roti|chapati|paratha|naan|dosa|appam)\b", re.I), "Breads & Bakes"),
    (re.compile(r"\b(cake|cookie|brownie|muffin|halwa|ladoo|kheer|pudding|dessert|sweet)\b", re.I), "Sweet Serenades"),
    (re.compile(r"\b(soup|rasam|broth|stew)\b", re.I), "Slow & Soulful"),
    (re.compile(r"\b(pickle|chutney|jam|preserve)\b", re.I), "Preserved & Cherished"),
    (re.compile(r"\b(salad|raita)\b", re.I), "Garden & Earth"),
    (
        re.compile(
            r"\b(mocktail|cocktail|martini|margarita|mojito|smoothie|juice|lassi|chai|tea|coffee|"
            r"drink|shake|protein shake|wine|beer|vodka|gin|rum|whiskey)\b",
            re.I,
        ),
        "Sips & Stories",
    ),
    (re.compile(r"\b(fish|prawn|shrimp|crab|seafood|meen)\b", re.I), "Ocean & River"),
    (re.compile(r"\b(chicken|mutton|lamb|beef|pork|meat)\b", re.I), "Meat & Fire"),
    (re.compile(r"\b(breakfast|pancake|waffle|omelette|porridge)\b", re.I), "Rise & Shine"),
]


def is_likely_non_recipe_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
    except ValueError:
        return True
    path = (parsed.path or "/").lower()
    if path in ("", "/"):
        return True
    return bool(NON_RECIPE_PATH.search(path))


def infer_sub_category(name: str, ingredient_lines: list[str]) -> str:
    blob = f"{name} {' '.join(ingredient_lines)}".lower()
    if re.search(r"\b(mocktail|virgin|non-alcoholic|sans alcohol)\b", blob):
        return "Mocktails"
    if re.search(r"\b(protein shake|protein drink|whey|smoothie|shake)\b", blob):
        return "Smoothies & Shakes"
    if re.search(r"\b(cocktail|martini|margarita|mojito|gin|vodka|rum|whiskey|spirit|wine|beer|sangria)\b", blob):
        return "Cocktails & Spirits"
    if re.search(r"\b(tea|coffee|chai|latte|espresso|cappuccino)\b", blob):
        return "Tea & Coffee"
    if re.search(r"\b(juice|lemonade|squash|refresher|lassi)\b", blob):
        return "Juices & Refreshers"
    return ""


def infer_category(name: str, ingredient_lines: list[str]) -> str:
    blob = f"{name} {' '.join(ingredient_lines)}".lower()
    for pattern, category in CATEGORY_RULES:
        if pattern.search(blob):
            return category
    if re.search(r"\b(rice|dal|lentil|grain)\b", blob):
        return "Grains & Comfort"
    if re.search(r"\b(vegetable|sabzi|curry|thoran)\b", blob):
        return "Garden & Earth"
    return "Grains & Comfort"


def html_to_text(fragment: str) -> str:
    text = re.sub(r"<script[\s\S]*?</script>", " ", fragment, flags=re.I)
    text = re.sub(r"<style[\s\S]*?</style>", " ", text, flags=re.I)
    text = re.sub(r"<br\s*/?>", "\n", text, flags=re.I)
    text = re.sub(r"</(p|div|h[1-6]|li|tr|section|article|ol|ul)>", "\n", text, flags=re.I)
    text = re.sub(r"<li[^>]*>", "\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html_lib.unescape(text)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_article_html(page_html: str) -> str:
    for pattern in (
        r'<div[^>]*class="[^"]*\bentry-content\b[^"]*"[^>]*>([\s\S]*)',
        r'<div[^>]*class="[^"]*\bwp-block-post-content\b[^"]*"[^>]*>([\s\S]*)',
        r"<article[^>]*>([\s\S]*?)</article>",
    ):
        match = re.search(pattern, page_html, re.I)
        if not match or len(match.group(1)) < 200:
            continue
        chunk = match.group(1)
        for stop in (r"<footer\b", r'id="comments"', r"Leave a Reply", r"Share this:"):
            idx = re.search(stop, chunk, re.I)
            if idx and idx.start() > 150:
                chunk = chunk[: idx.start()]
        return chunk
    return ""


def extract_json_ld_recipe(page_html: str) -> dict[str, Any] | None:
    for script in re.finditer(
        r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>([\s\S]*?)</script>',
        page_html,
        re.I,
    ):
        try:
            data = json.loads(script.group(1))
        except json.JSONDecodeError:
            continue
        candidates = data.get("@graph", [data]) if isinstance(data, dict) else data
        if not isinstance(candidates, list):
            candidates = [candidates]
        for item in candidates:
            if not isinstance(item, dict):
                continue
            item_type = item.get("@type")
            if item_type == "Recipe" or (isinstance(item_type, list) and "Recipe" in item_type):
                return item
    return None


def flatten_instructions(raw: Any) -> list[str]:
    if not raw:
        return []
    if isinstance(raw, str):
        return [raw.strip()] if raw.strip() else []
    steps: list[str] = []
    if not isinstance(raw, list):
        return steps
    for step in raw:
        if isinstance(step, str) and step.strip():
            steps.append(step.strip())
        elif isinstance(step, dict):
            text = step.get("text") or step.get("name") or ""
            if text:
                steps.append(str(text).strip())
            for sub in step.get("itemListElement") or []:
                if isinstance(sub, dict) and sub.get("text"):
                    steps.append(str(sub["text"]).strip())
    return steps


def parse_iso_minutes(value: Any) -> int:
    if not value:
        return 0
    text = str(value)
    hours = int(re.search(r"(\d+)H", text, re.I).group(1)) if re.search(r"(\d+)H", text, re.I) else 0
    minutes = int(re.search(r"(\d+)M", text, re.I).group(1)) if re.search(r"(\d+)M", text, re.I) else 0
    return hours * 60 + minutes


def parse_ingredient_line(line: str) -> dict[str, str] | None:
    line = line.strip().lstrip("-•* ").strip()
    if not line or len(line) < 2:
        return None
    if re.match(r"^ingredients?\s*:?\s*$", line, re.I):
        return None
    match = ING_LINE.match(line)
    if match:
        return {
            "qty": match.group(1).strip(),
            "unit": (match.group(2) or "").strip(),
            "ingredient": match.group(3).strip(),
            "note": "",
            "category": "",
        }
    return {"qty": "", "unit": "", "ingredient": line, "note": "", "category": ""}


def segment_article_text(text: str) -> dict[str, Any]:
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    ing_hdr = meth_hdr = -1
    for idx, line in enumerate(lines):
        if ing_hdr < 0 and re.match(r"^ingredients?\s*:?\s*$", line, re.I):
            ing_hdr = idx
        if meth_hdr < 0 and re.match(
            r"^(method|instructions?|directions?|how to make|procedure|steps?|prep work)\b",
            line,
            re.I,
        ):
            meth_hdr = idx

    ing_start = ing_hdr + 1 if ing_hdr >= 0 else 0
    meth_start = meth_hdr + 1 if meth_hdr >= 0 else -1
    if meth_start < 0:
        for idx, line in enumerate(lines):
            if re.match(r"^\d+[\.\):\-]\s+\S", line):
                meth_start = idx
                break

    ing_end = meth_hdr if meth_hdr >= 0 else len(lines)
    ing_lines = lines[ing_start:ing_end]
    meth_lines = lines[meth_start:] if meth_start >= 0 else []

    ingredients: list[str] = []
    for line in ing_lines:
        if re.match(r"^(ingredients?|method|how to make)\b", line, re.I):
            continue
        if JUNK_STEP.match(line):
            continue
        ingredients.append(line)

    method: list[str] = []
    for line in meth_lines:
        if JUNK_STEP.match(line) or re.match(r"^related posts?\b", line, re.I):
            break
        cleaned = re.sub(r"^\d+[\.\):\-]\s*", "", line).strip()
        if cleaned and len(cleaned) > 2:
            method.append(cleaned)

    title = ""
    for line in lines[:6]:
        if 4 < len(line) < 120 and not re.match(r"^(ingredients?|method)\b", line, re.I):
            title = line
            break

    return {"title": title, "ingredients": ingredients, "method": method}


def build_structured(
    *,
    title: str,
    ingredient_lines: list[str],
    method_steps: list[str],
    source_url: str,
    meta: dict[str, Any] | None = None,
) -> dict[str, Any]:
    meta = meta or {}
    clean_title = re.sub(r"\s*[-|–—]\s*Veena'?s?\s*Curry\s*World.*$", "", title, flags=re.I).strip()
    title_lower = clean_title.lower()
    ingredient_lines = [
        line
        for line in ingredient_lines
        if line.strip().lower() not in (title_lower, "ingredients", "method")
        and line.strip().lower() != title_lower
    ]
    items: list[dict[str, str]] = []
    for line in ingredient_lines:
        parsed = parse_ingredient_line(line)
        if parsed and parsed["ingredient"]:
            items.append(parsed)

    method = [{"title": "", "text": step} for step in method_steps if step and not JUNK_STEP.match(step)]

    category = infer_category(clean_title, ingredient_lines)
    sub_category = infer_sub_category(clean_title, ingredient_lines) if category == "Sips & Stories" else ""
    site_name = display_name_for_url(source_url)
    author = str(meta.get("author") or "").strip()
    chef = chef_name_for_url(source_url, author)

    raw = {
        "recipe_name": clean_title or "Untitled Recipe",
        "category": category,
        "sub_category": sub_category,
        "introduction": f"Imported from {site_name}. Original recipe: {source_url}",
        "prep_time_minutes": parse_iso_minutes(meta.get("prepTime")),
        "cook_time_minutes": parse_iso_minutes(meta.get("cookTime")),
        "servings": max(1, int(re.sub(r"[^\d]", "", str(meta.get("servings") or "1")) or "1")),
        "spice_level": "Not Applicable",
        "sweet_level": "Not Applicable",
        "ingredients": [{"section": "Ingredients", "items": items}] if items else [],
        "method": [{"section": "DIRECTIONS", "steps": method}] if method else [],
        "cooking_notes": "",
        "credit_name": chef,
        "credit_handle": "",
    }
    raw["category"] = normalize_choice(raw["category"], TCJ_CATEGORIES, raw["category"])
    return normalize_structured(raw)


def fetch_and_structure_url(url: str, timeout: int = 25) -> dict[str, Any]:
    if is_likely_non_recipe_url(url):
        return {"ok": False, "error": "URL looks like a homepage or category page, not a single recipe"}

    try:
        response = requests.get(url, headers=REQUEST_HEADERS, timeout=timeout)
    except requests.RequestException as exc:
        return {"ok": False, "error": str(exc)}

    if response.status_code != 200:
        return {"ok": False, "error": f"HTTP {response.status_code}", "http_status": response.status_code}

    page_html = response.text
    if len(page_html) < 200:
        return {"ok": False, "error": "Empty response"}

    host = urlparse(url).netloc.lower()
    recipe_ld = extract_json_ld_recipe(page_html)
    og_title = ""
    og = re.search(r'property=["\']og:title["\'][^>]*content=["\']([^"\']+)["\']', page_html, re.I)
    if og:
        og_title = html_lib.unescape(og.group(1)).strip()

    meta: dict[str, Any] = {}
    ingredient_lines: list[str] = []
    method_steps: list[str] = []
    extractor = "article-html"

    if recipe_ld:
        ingredient_lines = [
            str(x).strip()
            for x in (recipe_ld.get("recipeIngredient") or [])
            if str(x).strip()
        ]
        method_steps = flatten_instructions(recipe_ld.get("recipeInstructions"))
        meta = {
            "prepTime": recipe_ld.get("prepTime"),
            "cookTime": recipe_ld.get("cookTime"),
            "servings": recipe_ld.get("recipeYield"),
            "author": (
                recipe_ld.get("author", {}).get("name")
                if isinstance(recipe_ld.get("author"), dict)
                else recipe_ld.get("author")
            ),
        }
        title = str(recipe_ld.get("name") or og_title or "")
        if len(ingredient_lines) >= 2 and len(method_steps) >= 2:
            extractor = "jsonld"
        else:
            extractor = "jsonld-partial"
    else:
        title = og_title
        fragment = extract_article_html(page_html)
        article_text = html_to_text(fragment) if fragment else html_to_text(page_html[:120000])
        seg = segment_article_text(article_text)
        title = seg["title"] or title
        ingredient_lines = seg["ingredients"]
        method_steps = seg["method"]
        extractor = "wp-raw"

    structured = build_structured(
        title=title,
        ingredient_lines=ingredient_lines,
        method_steps=method_steps,
        source_url=url,
        meta=meta,
    )

    ing_count = sum(len(s.get("items") or []) for s in structured.get("ingredients") or [])
    step_count = sum(len(s.get("steps") or []) for s in structured.get("method") or [])
    ok = ing_count >= 2 and step_count >= 2 and structured["recipe_name"] != "Untitled Recipe"

    return {
        "ok": ok,
        "skipped": not ok,
        "reason": None if ok else f"quality gate: {ing_count} ingredients, {step_count} steps",
        "schema_version": "tcj-website-v1",
        "source_url": url,
        "host": host,
        "extractor": extractor,
        "extractor_version": "tcj-extract-py-v1",
        "parser_version": "website-batch-v1",
        "warnings": [],
        "structured": structured,
        "paste_snapshot": "\n".join(ingredient_lines + method_steps)[:12000],
        "source_display_name": display_name_for_url(url),
    }
