"""Batch-fix common HTML shell gaps (supabase, meta, canonical, style.css)."""
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), "..")
BASE = "https://theculinaryjournal.site"

META_BY_FILE = {
    "christmas-roast.html": "Plan Christmas roast timing — work backwards from serve time and export sides to grocery or meal planner.",
    "eid-feast.html": "Plan Eid feast mains, sides, and sweets — scale for guests and export to grocery or meal planner.",
    "credit-preservation.html": "How The Culinary Journal preserves recipe attribution and contributor credit.",
    "data-breach.html": "Data breach notification policy for The Culinary Journal members.",
    "event-seating-policy.html": "Event seating and table planner policies on The Culinary Journal.",
    "onam-sadya.html": "Plan an Onam sadya — traditional Kerala feast courses and timing.",
    "subscription-terms.html": "Subscription terms for Premium and paid plans on The Culinary Journal.",
    "checkout-success.html": "Your Culinary Journal subscription or purchase was successful.",
    "404.html": "Page not found — return to The Culinary Journal home or recipe browse.",
}

STYLE_CSS_PAGES = ["members-only.html", "paid-members-only.html"]


def inject_after_viewport(text, injection):
    if injection.strip() in text:
        return text
    m = re.search(r'(<meta name="viewport"[^>]*>)', text, re.I)
    if m:
        return text[: m.end()] + "\n" + injection + text[m.end() :]
    m = re.search(r"(<meta charset[^>]*>)", text, re.I)
    if m:
        return text[: m.end()] + "\n" + injection + text[m.end() :]
    return text


def ensure_supabase(text):
    if "supabase-config.js" in text or "nav-init.js" not in text:
        return text
    return text.replace(
        '<script src="nav-init.js"></script>',
        '<script src="supabase-config.js"></script>\n<script src="nav-init.js"></script>',
    )


def ensure_style_css(text, fname):
    if fname not in STYLE_CSS_PAGES or "style.css" in text:
        return text
    return inject_after_viewport(
        text,
        '  <link rel="stylesheet" href="style.css">',
    )


def ensure_meta_canonical(text, fname):
    title_m = re.search(r"<title>([^<]+)</title>", text, re.I)
    title = title_m.group(1).strip() if title_m else fname.replace(".html", "")
    desc = META_BY_FILE.get(fname) or re.sub(
        r"\s*[—–|-]\s*The Culinary Journal\s*$", "", title, flags=re.I
    ).strip()
    desc = desc + " — The Culinary Journal." if desc and "Culinary Journal" not in desc else desc
    injection = ""
    if 'name="description"' not in text:
        injection += f'  <meta name="description" content="{desc}">\n'
    if 'rel="canonical"' not in text:
        injection += f'  <link rel="canonical" href="{BASE}/{fname}">\n'
    if not injection:
        return text
    return inject_after_viewport(text, injection.rstrip())


for fname in sorted(f for f in os.listdir(ROOT) if f.endswith(".html")):
    path = os.path.join(ROOT, fname)
    text = open(path, encoding="utf-8", errors="replace").read()
    orig = text
    text = ensure_supabase(text)
    text = ensure_style_css(text, fname)
    text = ensure_meta_canonical(text, fname)
    if text != orig:
        open(path, "w", encoding="utf-8", newline="\n").write(text)
        print("fixed", fname)
