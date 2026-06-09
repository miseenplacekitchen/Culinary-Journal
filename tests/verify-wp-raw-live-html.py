#!/usr/bin/env python3
"""WP-raw family probe: live Kothiyavunu HTML -> text trim (no Node required)."""
import re
from pathlib import Path

FIXTURE = Path(__file__).parent / 'fixtures' / 'kothiyavunu-puttu-live.html'

BLOG_STOP = [
    re.compile(r'^related posts?', re.I),
    re.compile(r'^until next time', re.I),
    re.compile(r'^check here for more', re.I),
    re.compile(r'food advertisements by', re.I),
]


def strip_wp_noise(html: str) -> str:
    html = re.sub(r'<!--\s*Start GADSWPV[\s\S]*?<!--\s*End GADSWPV[\s\S]*?-->', '\n', html, flags=re.I)
    html = re.sub(r'Food Advertisements\s+by\s*', '\n', html, flags=re.I)
    return html


def html_to_text(fragment: str) -> str:
    t = re.sub(r'<script[\s\S]*?</script>', ' ', fragment, flags=re.I)
    t = re.sub(r'<style[\s\S]*?</style>', ' ', t, flags=re.I)
    t = re.sub(r'<br\s*/?>', '\n', t, flags=re.I)
    t = re.sub(r'</(p|div|h[1-6]|li)>', '\n', t, flags=re.I)
    t = re.sub(r'<[^>]+>', ' ', t)
    t = re.sub(r'&nbsp;', ' ', t, flags=re.I)
    t = re.sub(r'&#8211;|&ndash;', '-', t, flags=re.I)
    t = re.sub(r'[ \t]+\n', '\n', t)
    t = re.sub(r'\n{3,}', '\n\n', t)
    return t.strip()


def trim_blog(text: str) -> str:
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    lines = [ln for ln in lines if not re.match(r'^food advertisements by\s*$', ln, re.I)]
    start = next((i for i, l in enumerate(lines) if re.match(r'^ingredients?\s*:?\s*$', l, re.I)), 0)
    end = len(lines)
    saw_body = False
    for i in range(start, len(lines)):
        if re.match(r'^how\s+to\s+make\b', lines[i], re.I) or re.match(r'^\d+\.\s+', lines[i]):
            saw_body = True
        if any(p.search(lines[i]) for p in BLOG_STOP):
            if saw_body or not re.search(r'food advertisements', lines[i], re.I):
                end = i
                break
    return '\n'.join(lines[start:end])


def main():
    html = strip_wp_noise(FIXTURE.read_text(encoding='utf-8', errors='replace'))
    m = re.search(r'<div[^>]*class="[^"]*\bentry-content\b[^"]*"[^>]*>([\s\S]*)', html, re.I)
    chunk = m.group(1) if m else html
    cut = chunk.lower().find('related posts')
    if cut > 150:
        chunk = chunk[:cut]
    text = trim_blog(html_to_text(chunk))
    steps = re.findall(r'^\d+\.\s+.+', text, re.M)
    ings = [ln for ln in text.splitlines() if ':' in ln and not re.match(r'^\d+\.', ln)]
    print('trimmed_chars', len(text))
    print('ingredient_lines', len(ings))
    print('numbered_steps', len(steps))
    ok = len(ings) >= 4 and len(steps) >= 8
    print('PASS' if ok else 'FAIL')
    if not ok or '--verbose' in __import__('sys').argv:
        print('--- key lines ---')
        for ln in text.splitlines():
            if re.match(r'^\d+\.', ln) or re.match(r'^how\s+to\s+make', ln, re.I) or (
                ':' in ln and not re.match(r'^(preparation|cooking|serves?)', ln, re.I)
            ):
                print(ln[:120])
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
