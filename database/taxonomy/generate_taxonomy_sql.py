#!/usr/bin/env python3
"""Parse book-taxonomy.md and generate fix-book-taxonomy.sql + lib taxonomy JS."""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MD_PATH = Path(__file__).resolve().parent / "book-taxonomy.md"
SQL_PATH = ROOT / "database" / "sql" / "fix-book-taxonomy.sql"
GARDEN_SQL_PATH = ROOT / "database" / "sql" / "fix-garden-taxonomy.sql"
JS_PATH = ROOT / "lib" / "taxonomy-sub-codes.js"
PARTS_JS_PATH = ROOT / "lib" / "taxonomy-parts.js"
FOOD_INFER_JS_PATH = ROOT / "lib" / "food-taxonomy-infer.js"

# Sips uses drink-taxonomy-infer.js
SKIP_FOOD_INFER_CATEGORY_NUMS = {10}

GENERIC_INFER_WORDS = frozenset(
    {
        "other",
        "misc",
        "miscellaneous",
        "general",
        "basic",
        "simple",
        "classic",
        "traditional",
        "style",
        "styles",
        "dishes",
        "dish",
        "food",
        "foods",
        "recipe",
        "recipes",
        "guide",
        "reference",
        "notes",
        "adaptations",
        "preparations",
        "homemade",
        "how",
        "make",
        "cooking",
        "based",
        "mixed",
        "fresh",
        "regional",
        "global",
        "international",
        "asian",
        "indian",
        "european",
        "western",
        "middle",
        "eastern",
        "south",
        "north",
        "east",
        "west",
        "central",
    }
)

# High-priority disambiguation (regex, sub, div). div '' = sub only.
CURATED_FOOD_RULES: dict[str, list[tuple[str, str, str]]] = {
    "Grains & Comfort": [
        (r"\b(mutton biryani|goat biryani|beef biryani|lamb biryani)\b", "Mutton & Beef Biryani", ""),
        (r"\b(prawn biryani|fish biryani|crab biryani|seafood biryani)\b", "Seafood Biryani", ""),
        (r"\b(paneer biryani|mushroom biryani|veg biryani|vegetable biryani)\b", "Vegetarian Biryani", ""),
        (r"\b(chicken biryani|hyderabadi biryani|dum biryani|thalassery biryani|ambur biryani)\b", "Chicken Biryani", ""),
        (r"\b(biriyani|biryani)\b", "Chicken Biryani", ""),
        (r"\b(pulao|pilaf|pilau|yakhni pulao|matar pulao)\b", "Pulao", ""),
        (r"\b(plov|machboos|mujaddara|chelow)\b", "Middle Eastern & Central Asian Pilaf", ""),
        (r"\b(fried rice|nasi goreng)\b", "Chinese Fried Rice", ""),
        (r"\b(risotto|paella)\b", "International Rice Dishes", ""),
        (r"\b(ramen|udon|soba)\b", "Ramen", ""),
        (r"\b(spaghetti|carbonara|bolognese|lasagna|penne pasta)\b", "Tomato-Based Pasta", ""),
        (r"\b(khichdi|kitchari)\b", "Other Grain & Starch Dishes", ""),
    ],
    "Meat & Fire": [
        (r"\b(chicken 65|nadan chicken|chicken pakora|amritsari chicken|chicken sukka|kozhi varuval)\b", "South Asian Fried Chicken", ""),
        (r"\b(karaage|chicken katsu|yangnyeom|korean fried chicken|popcorn chicken)\b", "East & South-East Asian Fried Chicken", ""),
        (r"\b(fried chicken|southern fried|buttermilk chicken)\b", "Western Fried Chicken", ""),
        (r"\b(tandoori|tikka|seekh kebab|galouti|reshmi kebab|haryali kebab)\b", "Tandoor & Indian Grill", ""),
        (r"\b(shawarma|kebab|kofta kebab|doner)\b", "Middle Eastern & Mediterranean Grill", ""),
        (r"\b(yakitori|satay|bulgogi|galbi)\b", "East Asian Grill & Skewers", ""),
        (r"\b(bbq|barbecue|pulled pork|smoked ribs|brisket)\b", "Western & BBQ Roasts", ""),
        (r"\b(mutton|goat fry|goat roast|meen varuval)\b", "South Asian Dry Mutton & Goat", ""),
        (r"\b(beef steak|ribeye|sirloin|t-bone)\b", "Beef Steaks", ""),
        (r"\b(lamb chop|rack of lamb|lamb shank)\b", "Lamb & Pork Chops", ""),
        (r"\b(pork belly|pork roast|bacon fry)\b", "Pork Dry Dishes", ""),
    ],
    "Ocean & River": [
        (r"\b(fish and chips|fish fry|karimeen|meen varuval|amritsari fish)\b", "Whole Fish Fry", ""),
        (r"\b(prawn fry|prawn roast|chemmeen|jhinga fry)\b", "Fried & Dry Prawn Dishes", ""),
        (r"\b(fish curry|meen curry|malabar fish curry|goan fish curry)\b", "Coconut-Based Fish Curries", ""),
        (r"\b(prawn curry|chemmeen curry)\b", "Prawn Curries", ""),
        (r"\b(crab curry|nandu curry)\b", "Crab Curries", ""),
        (r"\b(sushi|sashimi|poke|ceviche)\b", "Cured & Smoked Fish", ""),
        (r"\b(grilled salmon|baked fish|poached fish)\b", "Grilled & Baked Fish", ""),
    ],
    "Slow & Soulful": [
        (r"\b(dal|daal|sambar|rassam|rasam)\b", "Indian Dal", ""),
        (r"\b(miso soup|ramen broth|pho|bone broth)\b", "Asian Broths & Soups", ""),
        (r"\b(haleem|nihari|tagine|pot roast|braised)\b", "Haleem & Slow Braises", ""),
        (r"\b(butter chicken|tikka masala|korma|vindaloo)\b", "North Indian & Pakistani Chicken Curries", ""),
        (r"\b(avial| olan| erissery)\b", "Coconut-Based Vegetarian Curries", ""),
    ],
    "Rise & Shine": [
        (r"\b(congee|jook|kanji|okayu|khao tom|champorado)\b", "Rice Porridges", ""),
        (r"\b(idli|rava idli|kanchipuram idli)\b", "Idlis", ""),
        (r"\b(dosa|masala dosa|neer dosa|rava dosa|pesarattu)\b", "Dosas", ""),
        (r"\b(appam|vellayappam|idiyappam|string hopper)\b", "Appams & Hoppers", ""),
        (r"\b(puttu|kozhukatta)\b", "Puttu & Steamed Rice Dishes", ""),
        (r"\b(pancake|waffle|french toast|crepe)\b", "Pancakes & Crepes", ""),
        (r"\b(omelette|omelet|frittata|scrambled egg|shakshuka)\b", "Omelettes", ""),
        (r"\b(paratha|thepla|aloo paratha)\b", "Indian Flatbreads (Breakfast)", ""),
        (r"\b(overnight oat|bircher|steel.?cut oat)\b", "Oat & Grain Porridges", ""),
        (r"\b(upma|rava upma)\b", "Semolina & Flour Porridges", ""),
    ],
    "The Evening Table": [
        (r"\b(pakora|bhajji|bajji|fritter)\b", "Vegetable Fritters & Pakoras", ""),
        (r"\b(paneer pakora|halloumi fries)\b", "Paneer & Cheese Fritters", ""),
        (r"\b(dumpling|gyoza|momos|dim sum)\b", "Asian Dumplings (Steamed)", ""),
        (r"\b(spring roll|samosa|vada pav|pani puri|bhel puri|chaat)\b", "Tossed & Assembled Chaat", ""),
        (r"\b(bruschetta|toast)\b", "Toasts & Bruschetta", ""),
        (r"\b(finger sandwich|tea sandwich|high tea)\b", "High Tea Finger Sandwiches", ""),
        (r"\b(scone)\b", "Scones", ""),
        (r"\b(satay|skewer)\b", "Skewers & Satay", ""),
    ],
    "Breads & Bakes": [
        (r"\b(sourdough|ciabatta|baguette|focaccia)\b", "Yeasted Loaves", ""),
        (r"\b(naan|roti|paratha|chapati|pita|lavash)\b", "Flatbreads", ""),
        (r"\b(croissant|danish|pain au chocolat)\b", "Croissants & Danish", ""),
        (r"\b(muffin|scone|dinner roll)\b", "Rolls & Small Breads", ""),
        (r"\b(pie|quiche|pot pie)\b", "Pies & Baked Casseroles", ""),
    ],
    "Sweet Serenades": [
        (r"\b(gulab jamun|jalebi|ladoo|barfi|halwa|rasgulla|laddu)\b", "Fried & Syrup-Soaked Sweets", ""),
        (r"\b(kheer|payasam|rice pudding)\b", "Milk-Based Sweets & Puddings", ""),
        (r"\b(ice cream|gelato)\b", "Ice Cream", ""),
        (r"\b(tiramisu|panna cotta|creme brulee)\b", "Custard-Based Desserts", ""),
        (r"\b(mousse|parfait)\b", "Mousse & Light Set Desserts", ""),
        (r"\b(truffle|bonbon|fudge)\b", "Truffles & Bonbons", ""),
    ],
    "Preserved & Cherished": [
        (r"\b(mango pickle|avakaya|achar)\b", "Mango Pickles", ""),
        (r"\b(kimchi|kkakdugi)\b", "Korean Kimchi", ""),
        (r"\b(sauerkraut)\b", "European Pickles", ""),
        (r"\b(coconut chutney|mint chutney|tomato chutney)\b", "Fresh Chutneys (South Indian)", ""),
        (r"\b(garam masala|biryani masala|curry powder)\b", "Kerala Spice Blends", ""),
        (r"\b(jam|marmalade|fruit preserve)\b", "Jams", ""),
    ],
    "Feast Days": [
        (r"\b(thanksgiving)\b", "Thanksgiving", ""),
        (r"\b(christmas|yule log|stollen|panettone)\b", "Christmas", ""),
        (r"\b(diwali)\b", "Diwali Sweets & Savouries", ""),
        (r"\b(eid|ramadan|iftar)\b", "Eid", ""),
        (r"\b(easter)\b", "Easter", ""),
        (r"\b(holi)\b", "Holi", ""),
        (r"\b(onam|sadya)\b", "Onam Sadya (Kerala)", ""),
    ],
    "Little Ones": [
        (r"\b(baby food|weaning|first food|puree baby|infant)\b", "Single Vegetable Purees", ""),
        (r"\b(toddler|finger food|blw|baby.?led weaning)\b", "Soft-Cooked Vegetable Finger Foods", ""),
        (r"\b(lunchbox|school lunch|packed lunch)\b", "Toddler Finger Foods & Snacks", ""),
    ],
    "Nourish & Heal": [
        (r"\b(keto|low.?carb)\b", "Low-GI Grain Dishes", ""),
        (r"\b(gluten.?free|celiac)\b", "Gluten-Free Flatbreads & Breads", ""),
        (r"\b(golden milk|haldi doodh|turmeric milk)\b", "Warming & Immunity Foods", ""),
        (r"\b(kanji|moong dal kanji|recovery soup)\b", "Recovery & Convalescence Foods", ""),
        (r"\b(postpartum|pathila|pathiam)\b", "Postpartum Recovery (Kerala / South Indian)", ""),
    ],
    "Garden & Earth": [
        (r"\b(thoran)\b", "Thoran & Stir-Fries (Coconut-Based)", ""),
        (r"\b(poriyal|varuval)\b", "Poriyal & Varuval (Tamil Style)", ""),
        (r"\b(mezhukkupuratti)\b", "Mezhukkupuratti (Stir-Fried in Oil)", ""),
        (r"\b(tofu stir|tofu fry|mapo tofu)\b", "Tofu Stir-Fries", ""),
        (r"\b(avial| olan)\b", "Thoran & Stir-Fries (Coconut-Based)", ""),
        (r"\b(roasted vegetable|roast veg)\b", "Roasted Vegetables", ""),
    ],
}

CATEGORY_MAP: dict[int, str] = {
    1: "Curds, Creams & Eggs",
    2: "Wrapped & Stuffed",
    3: "Garden & Earth",
    4: "Feather & Flock",
    5: "Ocean & River",
    6: "Pasture & Hoof",
    7: "The Grain Field",
    8: "Breads & Bakery",
    9: "Sweet Serenades",
    10: "Sips & Stories",
    11: "Preserved & Pantry",
    12: "Feast Days",
    13: "Little Ones",
    14: "Nourish & Heal",
}

# A–K ingredient-led categories use per-category seed SQL + fix-seed-hint-divisions.sql.
# Retired top-level categories (12–14) are not re-seeded from the book.
BOOK_SQL_EXCLUDE_NUMS = {3, 4, 5, 6, 7, 10, 12, 13, 14}
GARDEN_SQL_ONLY_NUMS = {3}

SIPS_SUB_CODES: dict[str, str] = {
    "Water & Sparkling": "A1",
    "Coffee": "A2",
    "Tea & Infusions": "A3",
    "Hot Chocolate & Warm Comforts": "A4",
    "Juices, Smoothies & Blends": "A5",
    "Milk, Plant Milks & Cultured Drinks": "A6",
    "Sodas, Tonics & Fizz": "A7",
    "Functional & Fermented": "A8",
    "Beer & Brewing": "B1",
    "Wine, Cider & Fermented Fruit": "B2",
    "Spirits & Liqueurs": "B3",
    "Cocktails & Mixed Drinks": "B4",
    "Syrups & Sweeteners": "C1",
    "Cordials, Squash & Concentrates": "C2",
    "Shrubs, Bitters & Infusions": "C3",
    "Garnishes, Ice & Glassware": "C4",
    "Techniques & Reference": "C5",
    "World Drinks": "D1",
    "By Season & Occasion": "D2",
    "For Kids": "D3",
    "Mocktails & Zero-Proof": "D4",
}

PHASE6_PLACEHOLDERS: dict[str, list[str]] = {
    "Garden & Earth": ["Vegetables", "Fruits", "Herbs & Greens", "Legumes & Pulses"],
    "Rise & Shine": ["Breakfast", "Brunch"],
    "The Evening Table": ["Mains", "Sides"],
    "Meat & Fire": ["Beef", "Poultry", "Lamb"],
    "Ocean & River": ["Fish", "Shellfish"],
    "Sweet Serenades": ["Cakes", "Pastries"],
    "Little Ones": ["Baby Food", "Family Favourites"],
}

RE_CATEGORY = re.compile(r"^(\d+)\.\s+(.+)$")
RE_PART = re.compile(r"^PART\s+([A-Z])\s+[—\-]\s+(.+)$", re.IGNORECASE)
RE_SUB = re.compile(r"^([A-Z])(\d+)\.\s+(.+)$")
RE_SEE_REF = re.compile(r"\(see\s+[^)]+\)\s*$", re.IGNORECASE)

PART_LETTER_EMOJI: dict[str, str] = {
    "A": "🥣",
    "B": "🍳",
    "C": "🥗",
    "D": "🌍",
    "E": "🎉",
    "F": "☕",
    "G": "🫙",
    "H": "💪",
}

SUB_EMOJI_RULES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"porridge|oat|gruel|congee|kanji", re.I), "🥣"),
    (re.compile(r"idli|dosa|appam|hopper|puttu|steamed batter", re.I), "🫓"),
    (re.compile(r"egg|omelette|frittata|scramble", re.I), "🍳"),
    (re.compile(r"pancake|waffle|crepe|french toast", re.I), "🥞"),
    (re.compile(r"bread|toast|muffin|bagel|croissant", re.I), "🍞"),
    (re.compile(r"soup|stew|broth|curry|dal|chowder", re.I), "🍲"),
    (re.compile(r"rice|biryani|pilaf|pulao|risotto", re.I), "🍚"),
    (re.compile(r"pasta|noodle|ramen|udon", re.I), "🍝"),
    (re.compile(r"beef|steak|burger|meatball", re.I), "🥩"),
    (re.compile(r"chicken|poultry|turkey|duck", re.I), "🍗"),
    (re.compile(r"pork|bacon|ham|sausage", re.I), "🥓"),
    (re.compile(r"lamb|mutton|goat", re.I), "🍖"),
    (re.compile(r"fish|salmon|tuna|cod|trout", re.I), "🐟"),
    (re.compile(r"shrimp|prawn|shellfish|crab|lobster|oyster", re.I), "🦐"),
    (re.compile(r"cake|cupcake|brownie|cookie|biscuit", re.I), "🍰"),
    (re.compile(r"pie|tart|pastry|danish", re.I), "🥧"),
    (re.compile(r"pickle|chutney|jam|preserve|ferment", re.I), "🫙"),
    (re.compile(r"salad|vegetable|greens|herb", re.I), "🥬"),
    (re.compile(r"dessert|sweet|pudding|ice cream|gelato", re.I), "🍮"),
    (re.compile(r"baby|toddler|kid|weaning", re.I), "👶"),
    (re.compile(r"health|diet|heal|nourish|therapeutic", re.I), "💪"),
    (re.compile(r"festive|feast|holiday|celebration", re.I), "🎉"),
    (re.compile(r"tea|coffee|evening|supper|dinner", re.I), "🍽"),
]

DIV_EMOJI_RULES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"chicken|poultry", re.I), "🍗"),
    (re.compile(r"beef|steak", re.I), "🥩"),
    (re.compile(r"pork|bacon|ham", re.I), "🥓"),
    (re.compile(r"lamb|mutton|goat", re.I), "🍖"),
    (re.compile(r"fish|salmon|tuna|cod", re.I), "🐟"),
    (re.compile(r"shrimp|prawn|shellfish|crab|lobster", re.I), "🦐"),
    (re.compile(r"vegetable|vegan|veggie|salad", re.I), "🥬"),
    (re.compile(r"rice|biryani|pilaf|pulao", re.I), "🍚"),
    (re.compile(r"soup|stew|broth", re.I), "🍲"),
    (re.compile(r"bread|flatbread|naan|roti", re.I), "🫓"),
    (re.compile(r"cake|cupcake|brownie", re.I), "🍰"),
    (re.compile(r"cookie|biscuit", re.I), "🍪"),
    (re.compile(r"pickle|chutney|jam", re.I), "🫙"),
    (re.compile(r"egg|omelette", re.I), "🍳"),
    (re.compile(r"pancake|waffle", re.I), "🥞"),
    (re.compile(r"idli|dosa", re.I), "🫓"),
    (re.compile(r"curry|masala", re.I), "🍛"),
    (re.compile(r"pasta|noodle", re.I), "🍝"),
    (re.compile(r"ice cream|sorbet|gelato", re.I), "🍨"),
    (re.compile(r"pie|tart", re.I), "🥧"),
]


@dataclass
class Division:
    name: str


@dataclass
class Subcategory:
    code: str
    name: str
    sort_order: int
    part_letter: str = ""
    part_title: str = ""
    divisions: list[Division] = field(default_factory=list)


@dataclass
class Category:
    num: int
    title: str
    db_name: str
    subs: list[Subcategory] = field(default_factory=list)


def sort_order_for_sub(part_letter: str, sub_num: int) -> int:
    part_index = ord(part_letter.upper()) - ord("A") + 1
    return part_index * 100 + sub_num * 10


def is_skip_line(line: str) -> bool:
    if not line.strip():
        return True
    if line.startswith("See "):
        return True
    if RE_CATEGORY.match(line):
        return True
    if RE_PART.match(line):
        return True
    if RE_SUB.match(line):
        return True
    return False


def is_cross_reference_line(line: str) -> bool:
    return bool(RE_SEE_REF.search(line.strip()))


def division_subtitle(name: str) -> str:
    for sep in (" / ", " (", ", "):
        if sep in name:
            return name.split(sep, 1)[0].strip()
    return ""


def emoji_for_sub(name: str, part_letter: str) -> str:
    for pattern, emoji in SUB_EMOJI_RULES:
        if pattern.search(name):
            return emoji
    return PART_LETTER_EMOJI.get(part_letter.upper(), "🍽")


def emoji_for_div(name: str, sub_name: str, part_letter: str) -> str:
    for pattern, emoji in DIV_EMOJI_RULES:
        if pattern.search(name):
            return emoji
    return emoji_for_sub(sub_name, part_letter)


def sql_str(value: str) -> str:
    return value.replace("'", "''")


def parse_taxonomy(text: str) -> tuple[list[Category], list[str]]:
    warnings: list[str] = []
    categories: list[Category] = []
    current_cat: Category | None = None
    current_part_letter: str | None = None
    current_part_title: str | None = None
    current_sub: Subcategory | None = None
    seen_part = False
    in_category_intro = False

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        stripped = line.strip()
        if not stripped:
            continue

        cat_match = RE_CATEGORY.match(stripped)
        if cat_match:
            num = int(cat_match.group(1))
            title = cat_match.group(2).strip()
            db_name = CATEGORY_MAP.get(num)
            if not db_name:
                warnings.append(f"Unknown category number {num}: {title}")
                continue
            current_cat = Category(num=num, title=title, db_name=db_name)
            categories.append(current_cat)
            current_part_letter = None
            current_part_title = None
            current_sub = None
            seen_part = False
            in_category_intro = True
            continue

        if current_cat is None:
            warnings.append(f"Line outside category: {stripped[:80]}")
            continue

        part_match = RE_PART.match(stripped)
        if part_match:
            current_part_letter = part_match.group(1).upper()
            current_part_title = part_match.group(2).strip()
            current_sub = None
            seen_part = True
            in_category_intro = False
            continue

        sub_match = RE_SUB.match(stripped)
        if sub_match:
            if current_part_letter is None:
                warnings.append(
                    f"{current_cat.db_name}: sub '{stripped}' before any PART"
                )
            part_letter = sub_match.group(1).upper()
            sub_num = int(sub_match.group(2))
            sub_name = sub_match.group(3).strip()
            code = f"{part_letter}{sub_num}"
            current_sub = Subcategory(
                code=code,
                name=sub_name,
                sort_order=sort_order_for_sub(part_letter, sub_num),
                part_letter=part_letter,
                part_title=current_part_title or "",
            )
            current_cat.subs.append(current_sub)
            in_category_intro = False
            continue

        if is_skip_line(stripped):
            continue

        if is_cross_reference_line(stripped):
            continue

        if in_category_intro and not seen_part:
            continue

        if current_sub is None:
            if current_part_letter is None:
                warnings.append(
                    f"{current_cat.db_name}: orphan line '{stripped[:60]}'"
                )
                continue
            sub_name = current_part_title or f"Part {current_part_letter}"
            code = f"{current_part_letter}1"
            current_sub = Subcategory(
                code=code,
                name=sub_name,
                sort_order=sort_order_for_sub(current_part_letter, 1),
                part_letter=current_part_letter,
                part_title=current_part_title or "",
            )
            current_cat.subs.append(current_sub)
            warnings.append(
                f"{current_cat.db_name}: synthesized sub '{sub_name}' ({code}) for PART {current_part_letter}"
            )

        current_sub.divisions.append(Division(name=stripped))

    return categories, warnings


def generate_sql(
    categories: list[Category],
    *,
    header: str,
    include_nums: set[int] | None = None,
    exclude_nums: set[int] | None = None,
    verify_exclude_garden: bool = True,
) -> str:
    lines: list[str] = [
        header,
        "-- Generated by database/taxonomy/generate_taxonomy_sql.py — safe to re-run.",
        "",
    ]

    active_categories = [
        c
        for c in categories
        if (include_nums is None or c.num in include_nums)
        and (exclude_nums is None or c.num not in exclude_nums)
    ]

    for cat in active_categories:
        db = cat.db_name
        new_sub_names = [s.name for s in cat.subs]
        placeholders = PHASE6_PLACEHOLDERS.get(db, [])

        lines.append(f"-- ── {db} ─────────────────────────────────────────────────────────────")
        lines.append("")

        if placeholders:
            quoted = ", ".join(f"'{sql_str(n)}'" for n in placeholders)
            lines.append(
                f"UPDATE public.recipe_subcategories SET is_active = false\n"
                f"WHERE category = '{sql_str(db)}'\n"
                f"  AND name IN ({quoted});"
            )
            lines.append("")

        if new_sub_names:
            quoted_new = ", ".join(f"'{sql_str(n)}'" for n in new_sub_names)
            lines.append(
                f"UPDATE public.recipe_subcategories SET is_active = false\n"
                f"WHERE category = '{sql_str(db)}'\n"
                f"  AND name NOT IN ({quoted_new});"
            )
            lines.append("")

        if cat.subs:
            lines.append(
                "INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES"
            )
            sub_rows: list[str] = []
            for sub in cat.subs:
                sub_rows.append(
                    f"  ('{sql_str(db)}', '{sql_str(sub.name)}', {sub.sort_order}, true)"
                )
            lines.append(",\n".join(sub_rows))
            lines.append("ON CONFLICT (category, name) DO UPDATE SET")
            lines.append("  sort_order = EXCLUDED.sort_order,")
            lines.append("  is_active = EXCLUDED.is_active;")
            lines.append("")

    lines.append("-- ── Divisions ─────────────────────────────────────────────────────────────────")
    lines.append("")
    lines.append(
        "INSERT INTO public.recipe_divisions (category, subcategory, name, emoji, subtitle, description, sort_order, is_active) VALUES"
    )

    div_rows: list[str] = []
    active_div_pairs: dict[str, list[tuple[str, str]]] = {}
    for cat in active_categories:
        pairs: list[tuple[str, str]] = []
        for sub in cat.subs:
            for idx, div in enumerate(sub.divisions, start=1):
                subtitle = division_subtitle(div.name)
                subtitle_sql = f"'{sql_str(subtitle)}'" if subtitle else "''"
                emoji = emoji_for_div(div.name, sub.name, sub.part_letter)
                div_rows.append(
                    f"  ('{sql_str(cat.db_name)}', '{sql_str(sub.name)}', "
                    f"'{sql_str(div.name)}', '{emoji}', {subtitle_sql}, "
                    f"'{sql_str(div.name)}', {idx}, true)"
                )
                pairs.append((sub.name, div.name))
        active_div_pairs[cat.db_name] = pairs

    if div_rows:
        lines.append(",\n".join(div_rows))
    lines.append("ON CONFLICT (category, subcategory, name) DO UPDATE SET")
    lines.append("  sort_order = EXCLUDED.sort_order,")
    lines.append("  is_active = true,")
    lines.append("  emoji = EXCLUDED.emoji,")
    lines.append("  subtitle = EXCLUDED.subtitle,")
    lines.append("  description = EXCLUDED.description;")
    lines.append("")

    lines.append("-- ── Deactivate orphaned legacy divisions ───────────────────────────────────────")
    lines.append("")
    for cat in active_categories:
        db = cat.db_name
        pairs = active_div_pairs.get(db, [])
        if not pairs:
            continue
        pair_sql = ", ".join(
            f"('{sql_str(sub)}', '{sql_str(div)}')" for sub, div in pairs
        )
        lines.append(
            f"UPDATE public.recipe_divisions SET is_active = false\n"
            f"WHERE category = '{sql_str(db)}'\n"
            f"  AND (subcategory, name) NOT IN ({pair_sql});"
        )
        lines.append("")

    if verify_exclude_garden:
        lines.append("-- Verify (book categories — Garden & Sips seeded separately)")
        lines.append("SELECT category, count(*) FILTER (WHERE kind = 'sub') AS subs,")
        lines.append("       count(*) FILTER (WHERE kind = 'div') AS divisions")
        lines.append("FROM (")
        lines.append("  SELECT category, 'sub' AS kind FROM public.recipe_subcategories")
        lines.append("  WHERE is_active = true AND category NOT IN ('Sips & Stories', 'Garden & Earth')")
        lines.append("  UNION ALL")
        lines.append("  SELECT category, 'div' FROM public.recipe_divisions")
        lines.append("  WHERE is_active = true AND category NOT IN ('Sips & Stories', 'Garden & Earth')")
        lines.append(") t")
        lines.append("GROUP BY category")
        lines.append("ORDER BY category;")
    else:
        db_names = sorted({c.db_name for c in active_categories})
        quoted = ", ".join(f"'{sql_str(n)}'" for n in db_names)
        lines.append("-- Verify")
        lines.append("SELECT category, count(*) FILTER (WHERE kind = 'sub') AS subs,")
        lines.append("       count(*) FILTER (WHERE kind = 'div') AS divisions")
        lines.append("FROM (")
        lines.append("  SELECT category, 'sub' AS kind FROM public.recipe_subcategories")
        lines.append(f"  WHERE is_active = true AND category IN ({quoted})")
        lines.append("  UNION ALL")
        lines.append("  SELECT category, 'div' FROM public.recipe_divisions")
        lines.append(f"  WHERE is_active = true AND category IN ({quoted})")
        lines.append(") t")
        lines.append("GROUP BY category")
        lines.append("ORDER BY category;")

    return "\n".join(lines) + "\n"


def generate_js(categories: list[Category]) -> str:
    mapping: dict[str, dict[str, str]] = {}
    for cat in categories:
        if cat.num == 10:
            continue
        mapping[cat.db_name] = {sub.name: sub.code for sub in cat.subs}
    mapping["Sips & Stories"] = dict(SIPS_SUB_CODES)

    body = json.dumps(mapping, indent=2, ensure_ascii=False)
    return f"window.TAXONOMY_SUB_CODES = {body};\n"


function generate_parts_js(categories: list[Category]) -> str:
    mapping: dict[str, dict[str, dict[str, object]]] = {}
    for cat in categories:
        if cat.num in BOOK_SQL_EXCLUDE_NUMS:
            continue
        parts: dict[str, dict[str, object]] = {}
        for sub in cat.subs:
            letter = sub.part_letter or (sub.code[0] if sub.code else "A")
            if letter not in parts:
                parts[letter] = {
                    "title": sub.part_title or f"Part {letter}",
                    "emoji": PART_LETTER_EMOJI.get(letter, "🍽"),
                    "subs": [],
                }
            subs_list = parts[letter]["subs"]
            assert isinstance(subs_list, list)
            if sub.name not in subs_list:
                subs_list.append(sub.name)
        mapping[cat.db_name] = parts

    body = json.dumps(mapping, indent=2, ensure_ascii=False)
    return f"window.TAXONOMY_PARTS = {body};\n"


@dataclass
class FoodInferRule:
    pattern: str
    sub: str
    div: str
    priority: int


SHORT_INFER_WORDS = frozenset(
    {
        "idli",
        "dosa",
        "paneer",
        "ramen",
        "udon",
        "soba",
        "pho",
        "kimchi",
        "puttu",
        "appam",
        "vada",
        "naan",
        "roti",
        "dal",
        "pho",
        "bun",
        "pie",
        "jam",
        "halwa",
        "ladoo",
        "jalebi",
        "barfi",
        "scone",
        "chaat",
        "pakora",
        "satay",
        "tempura",
        "sushi",
        "poke",
        "eid",
        "holi",
        "onam",
        "avial",
        "olan",
        "thoran",
        "poriyal",
        "upma",
        "congee",
        "kanji",
        "puttu",
        "haleem",
        "biryani",
        "pulao",
        "pilaf",
        "risotto",
        "paella",
        "schnitzel",
    }
)


def infer_words(text: str) -> list[str]:
    return re.findall(r"[a-z0-9']+", text.lower())


def significant_word_count(phrase: str) -> int:
    return sum(
        1
        for w in infer_words(phrase)
        if (len(w) > 2 or w in SHORT_INFER_WORDS) and w not in GENERIC_INFER_WORDS
    )


def phrases_from_label(label: str) -> list[str]:
    phrases: list[str] = []
    for match in re.finditer(r"\(([^)]+)\)", label):
        alias = match.group(1).strip()
        if len(alias) >= 4:
            phrases.append(alias)
    base = re.sub(r"\([^)]*\)", "", label).strip()
    for part in re.split(r"[/,&]", base):
        part = part.strip()
        if len(part) >= 4:
            phrases.append(part)
    if len(base) >= 4:
        phrases.append(base)
    seen: set[str] = set()
    out: list[str] = []
    for phrase in sorted(phrases, key=len, reverse=True):
        key = phrase.lower()
        if key not in seen:
            seen.add(key)
            out.append(phrase)
    return out


def phrase_to_regex(phrase: str) -> str | None:
    words = [
        w
        for w in infer_words(phrase)
        if w not in GENERIC_INFER_WORDS and (len(w) > 2 or w in SHORT_INFER_WORDS)
    ]
    if not words:
        return None
    if len(words) == 1:
        word = words[0]
        if len(word) < 5 and word not in SHORT_INFER_WORDS:
            return None
        return rf"\b{re.escape(word)}\b"
    return r"\b" + r"\s+".join(re.escape(w) for w in words[:6]) + r"\b"


def division_rules_for_category(cat: Category) -> list[FoodInferRule]:
    rules: list[FoodInferRule] = []
    valid_subs = {sub.name for sub in cat.subs}
    for sub in cat.subs:
        for div in sub.divisions:
            for phrase in phrases_from_label(div.name):
                if significant_word_count(phrase) < 1 and len(phrase) < 8:
                    continue
                pattern = phrase_to_regex(phrase)
                if not pattern:
                    continue
                rules.append(
                    FoodInferRule(
                        pattern=pattern,
                        sub=sub.name,
                        div=div.name,
                        priority=len(phrase) + (20 if sub.name in valid_subs else 0),
                    )
                )
    rules.sort(key=lambda r: r.priority, reverse=True)
    deduped: list[FoodInferRule] = []
    seen_patterns: set[str] = set()
    for rule in rules:
        if rule.pattern in seen_patterns:
            continue
        seen_patterns.add(rule.pattern)
        deduped.append(rule)
    return deduped


def curated_rules_for_category(cat_name: str, valid_subs: set[str]) -> list[FoodInferRule]:
    rules: list[FoodInferRule] = []
    for idx, (pattern, sub, div) in enumerate(CURATED_FOOD_RULES.get(cat_name, [])):
        if sub not in valid_subs:
            continue
        rules.append(
            FoodInferRule(pattern=pattern, sub=sub, div=div, priority=10_000 - idx)
        )
    return rules


def build_food_infer_rules(categories: list[Category]) -> dict[str, list[FoodInferRule]]:
    out: dict[str, list[FoodInferRule]] = {}
    for cat in categories:
        if cat.num in SKIP_FOOD_INFER_CATEGORY_NUMS:
            continue
        valid_subs = {sub.name for sub in cat.subs}
        merged: list[FoodInferRule] = []
        merged.extend(curated_rules_for_category(cat.db_name, valid_subs))
        merged.extend(division_rules_for_category(cat))
        merged.sort(key=lambda r: r.priority, reverse=True)
        deduped: list[FoodInferRule] = []
        seen: set[str] = set()
        for rule in merged:
            if rule.pattern in seen:
                continue
            seen.add(rule.pattern)
            deduped.append(rule)
        out[cat.db_name] = deduped
    return out


def js_rule_object(rule: FoodInferRule) -> str:
    pat = json.dumps(rule.pattern)
    sub = json.dumps(rule.sub, ensure_ascii=False)
    div = json.dumps(rule.div, ensure_ascii=False)
    return f"    {{ re: new RegExp({pat}, 'i'), sub: {sub}, div: {div} }}"


def generate_food_infer_js(categories: list[Category]) -> str:
    rules_by_cat = build_food_infer_rules(categories)
    lines = [
        "/**",
        " * Food categories — sub-category + division inference from recipe name/ingredients.",
        " * Generated by database/taxonomy/generate_taxonomy_sql.py — do not edit by hand.",
        " * Sips & Stories uses lib/drink-taxonomy-infer.js instead.",
        " */",
        "(function (root) {",
        "  'use strict';",
        "",
        "  var RULES = {",
    ]
    cat_names = sorted(rules_by_cat.keys())
    for idx, cat_name in enumerate(cat_names):
        rules = rules_by_cat[cat_name]
        lines.append(f"    {json.dumps(cat_name, ensure_ascii=False)}: [")
        if rules:
            lines.append(",\n".join(js_rule_object(r) for r in rules))
        lines.append("    ]" + ("," if idx < len(cat_names) - 1 else ""))
    lines.extend(
        [
            "  };",
            "",
            "  function infer(category, blob) {",
            "    var text = String(blob || '').toLowerCase().replace(/\\s+/g, ' ');",
            "    var out = { sub: '', div: '' };",
            "    if (!category || !text) return out;",
            "    var list = RULES[category];",
            "    if (!list) return out;",
            "    for (var i = 0; i < list.length; i++) {",
            "      if (list[i].re.test(text)) {",
            "        out.sub = list[i].sub;",
            "        out.div = list[i].div || '';",
            "        return out;",
            "      }",
            "    }",
            "    return out;",
            "  }",
            "",
            "  root.FoodTaxonomyInfer = { infer: infer, RULES: RULES };",
            "})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this);",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    text = MD_PATH.read_text(encoding="utf-8")
    categories, warnings = parse_taxonomy(text)

    SQL_PATH.parent.mkdir(parents=True, exist_ok=True)
    JS_PATH.parent.mkdir(parents=True, exist_ok=True)

    SQL_PATH.write_text(
        generate_sql(
            categories,
            header=(
                "-- fix-book-taxonomy.sql\n"
                "-- Book taxonomy (categories 1–2, 4–9, 11–14). "
                "Garden & Earth → fix-garden-taxonomy.sql. Sips → fix-sips-drinks-taxonomy.sql."
            ),
            exclude_nums=BOOK_SQL_EXCLUDE_NUMS,
            verify_exclude_garden=True,
        ),
        encoding="utf-8",
    )
    GARDEN_SQL_PATH.write_text(
        generate_sql(
            categories,
            header=(
                "-- fix-garden-taxonomy.sql\n"
                "-- Garden & Earth taxonomy (category 3). Keeps dishes/recipes table content; "
                "deactivates legacy Vegetables/Fruits placeholders."
            ),
            include_nums=GARDEN_SQL_ONLY_NUMS,
            verify_exclude_garden=False,
        ),
        encoding="utf-8",
    )
    JS_PATH.write_text(generate_js(categories), encoding="utf-8")
    PARTS_JS_PATH.write_text(generate_parts_js(categories), encoding="utf-8")
    FOOD_INFER_JS_PATH.write_text(generate_food_infer_js(categories), encoding="utf-8")

    print(f"Wrote {SQL_PATH}")
    print(f"Wrote {GARDEN_SQL_PATH}")
    print(f"Wrote {JS_PATH}")
    print(f"Wrote {PARTS_JS_PATH}")
    print(f"Wrote {FOOD_INFER_JS_PATH}")
    print()
    print("Counts per category (subs, divisions):")
    for cat in categories:
        if cat.num in BOOK_SQL_EXCLUDE_NUMS:
            if cat.num == 10:
                print(f"  [{cat.num:2d}] {cat.db_name}: fix-sips-drinks-taxonomy.sql")
            elif cat.num == 3:
                print(f"  [{cat.num:2d}] {cat.db_name}: fix-garden-taxonomy.sql")
            else:
                print(f"  [{cat.num:2d}] {cat.db_name}: separate SQL")
            continue
        div_count = sum(len(s.divisions) for s in cat.subs)
        print(f"  [{cat.num:2d}] {cat.db_name}: {len(cat.subs)} subs, {div_count} divisions")

    if warnings:
        print()
        print(f"Parse warnings ({len(warnings)}):")
        for w in warnings:
            print(f"  - {w}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
