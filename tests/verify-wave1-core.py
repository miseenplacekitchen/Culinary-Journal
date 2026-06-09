#!/usr/bin/env python3
"""Verify recipe-import-core colon splitting + step extraction (no Node required)."""
import re
import json

META_LABEL = re.compile(
    r'^(preparation\s+time|cooking\s+time|serves?|servings?|yield|ingredients?|method|directions?)$',
    re.I,
)
NEXT_ING = re.compile(r"\s+(?=[A-Z][a-z][A-Za-z0-9\s/'()./\u00C0-\u024F-]{1,58}?\s*:\s*)")


def split_colon_markers(blob):
    text = re.sub(r'\s+', ' ', str(blob or '')).strip()
    if not text:
        return []
    text = re.sub(r'\s*how\s+to\s+make\b.*$', '', text, flags=re.I).strip()
    out = []

    def parse_remainder(chunk):
        chunk = str(chunk or '').strip()
        if not chunk:
            return
        m = re.search(r'\s*:\s*', chunk)
        if not m:
            return
        name = chunk[:m.start()].strip()
        after = chunk[m.end():]
        if not name or META_LABEL.match(name) or re.match(r'^how\s+to\s+make\b', name, re.I):
            return
        nm = NEXT_ING.search(after)
        qty = after[:nm.start()].strip() if nm else after.strip()
        rest = after[nm.start():].strip() if nm else ''
        qty = re.sub(r'\s*how\s+to\s+make\b.*$', '', qty, flags=re.I).strip()
        if not qty and re.search(r'taste|as needed|to taste', name, re.I):
            out.append(name + ' :')
        elif qty:
            out.append(name + ' : ' + qty)
        elif len(name) > 2:
            out.append(name + ' :')
        if rest:
            parse_remainder(rest)

    parse_remainder(text)
    return out


def extract_numbered_steps(blob):
    text = re.sub(r'\s+', ' ', str(blob or '')).strip()
    text = re.sub(r'^how\s+to\s+make\b[^\n]*:?\s*', '', text, flags=re.I)
    steps = []
    for m in re.finditer(r'(\d+)\.\s+([\s\S]*?)(?=\s+\d+\.\s+|$)', text):
        step = re.sub(r'\s+', ' ', m.group(2)).strip()
        if len(step) > 4:
            steps.append(step)
    return steps


blob_ing = (
    'Wheat Flour /Atta : 2 cups Grated Coconut : 1 cup Water : 3/4 cup or enough to moisten the flour Salt to taste :'
)
blob_steps = (
    '1. Dry roast wheat flour. 2. Add salt to water. 3. Wet the flour. 4. Pulse in mixer. '
    '5. Optional coconut. 6. Fill cooker. 7. Layer tube. 8. Steam 6-8 minutes. 9. Serve hot with curry.'
)

parts = split_colon_markers(blob_ing)
steps = extract_numbered_steps(blob_steps)
ing_checks = {
    'count': len(parts) == 4,
    'wheat': bool(re.search(r'Wheat Flour.*:\s*2 cups$', parts[0], re.I)) if len(parts) > 0 else False,
    'coconut': bool(re.search(r'Grated Coconut.*:\s*1 cup$', parts[1], re.I)) if len(parts) > 1 else False,
    'water': bool(re.search(r'Water.*:\s*3/4 cup', parts[2], re.I)) if len(parts) > 2 else False,
    'salt': 'Salt to taste' in (parts[3] if len(parts) > 3 else ''),
}
step_checks = {'count': len(steps) >= 8}
pass_all = all(ing_checks.values()) and all(step_checks.values())
print(json.dumps({
    'pass': pass_all,
    'ingredients': parts,
    'ing_checks': ing_checks,
    'step_count': len(steps),
    'steps': steps,
}, indent=2))
raise SystemExit(0 if pass_all else 1)
