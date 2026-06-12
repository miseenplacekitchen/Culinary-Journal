"""Replace silent catch blocks with TcjErr.warn / TcjErr.ignore / TcjErr.rpcFallback."""
import re
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
exts = {".html", ".js"}
skip_dirs = {"node_modules", ".git", "tests", "fixtures"}
skip_files = {"lib/tcj-errors.js", "scripts/_audit-silent-failures.py", "scripts/_fix-silent-failures.py"}

INTENTIONAL_RE = re.compile(
    r"localStorage\.|setSelectionRange|revokeObjectURL|new\s+URL\s*\(|"
    r"dispatchEvent\s*\(|JSON\.parse\s*\(\s*localStorage|"
    r"getElementById\s*\(\s*['\"]tab-",
    re.I,
)

def ctx_from_preceding(pre: str, fname: str, line: int) -> str:
    pre = pre[-300:]
    m = re.search(r"(?:await\s+)?(?:rpc|fetch|notifRpc)\s*\(\s*['\"](\w+)", pre)
    if m:
        return m.group(1)
    for fn in ("validateIngredient", "validateUnit", "validateTool", "validateAllIngredientRows",
               "validateAllToolRows", "populateCategorySelects", "applyIngredientDbMatch",
               "tryRefreshToken", "mark_notification_read", "loadNotifCount", "switchTab",
               "clearDraftStorage", "extractJsonLdRecipe", "cleanupOcrText"):
        if fn in pre:
            return fn
    if INTENTIONAL_RE.search(pre):
        return "degrade"
    return f"{fname}:{line}"


def classify_catch_body(body: str, preceding: str) -> str:
    body_stripped = re.sub(r"\s+", " ", body.strip())
    if body_stripped == "" or body_stripped == "//":
        if INTENTIONAL_RE.search(preceding):
            return "ignore"
        return "warn"
    m = re.match(r"return\s+(null|\[\]|false)\s*;?\s*(//.*)?$", body_stripped)
    if m:
        return "rpc:" + m.group(1)
    if "/*" in body_stripped or "//" in body_stripped and len(body_stripped) < 40:
        return "ignore"
    return "warn"


def patch_text(text: str, rel: str) -> tuple[str, int]:
    changes = 0
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # Multi-line catch detection
        catch_m = re.search(r"catch\s*\(\s*(\w+)\s*\)\s*\{", line)
        if catch_m:
            var = catch_m.group(1)
            start = line.index("{")
            depth = line.count("{") - line.count("}")
            body_lines = [line[start + 1 :]]
            j = i
            if depth <= 0:
                j = i + 1
                while j < len(lines) and depth <= 0:
                    body_lines.append(lines[j])
                    depth += lines[j].count("{") - lines[j].count("}")
                    j += 1
            else:
                j = i + 1
                while j < len(lines) and depth > 0:
                    body_lines.append(lines[j])
                    depth += lines[j].count("{") - lines[j].count("}")
                    j += 1
            full_block = "\n".join(lines[i:j])
            body_inner = re.sub(r"^.*?catch\s*\([^)]*\)\s*\{", "", full_block, count=1)
            body_inner = re.sub(r"\}\s*$", "", body_inner.rstrip())
            preceding = "\n".join(lines[max(0, i - 8) : i + 1])
            action = classify_catch_body(body_inner, preceding)
            ctx = ctx_from_preceding(preceding, rel, i + 1)

            if action == "ignore":
                new_catch = f"catch ({var}) {{ TcjErr.ignore({var}); }}"
            elif action.startswith("rpc:"):
                val = action.split(":")[1]
                fb = "null" if val == "null" else ("[]" if val == "[]" else "false")
                new_catch = f"catch ({var}) {{ return TcjErr.rpcFallback('{ctx}', {var}, {fb}); }}"
            else:
                new_catch = f"catch ({var}) {{ TcjErr.warn('{ctx}', {var}); }}"

            # Replace only the catch clause opening + body if empty/simple
            if re.search(r"catch\s*\(\s*" + re.escape(var) + r"\s*\)\s*\{[^}]*\}", full_block, re.S):
                new_block = re.sub(
                    r"catch\s*\(\s*" + re.escape(var) + r"\s*\)\s*\{[^}]*\}",
                    new_catch,
                    full_block,
                    count=1,
                    flags=re.S,
                )
                if new_block != full_block:
                    out.extend(new_block.split("\n"))
                    changes += 1
                    i = j
                    continue
        out.append(line)
        i += 1

    text2 = "\n".join(out)

    # Promise .catch empty
    def repl_pcatch(m):
        nonlocal changes
        changes += 1
        inner = m.group(1)
        if "return" in inner:
            rm = re.search(r"return\s+(null|\[\]|false|0)", inner)
            if rm:
                fb = rm.group(1)
                return f".catch(function(e){{ return TcjErr.rpcFallback('{rel}', e, {fb}); }})"
        return f".catch(function(e){{ TcjErr.warn('{rel}', e); }})"

    text2 = re.sub(
        r"\.catch\s*\(\s*function\s*\([^)]*\)\s*\{([^}]*)\}\s*\)",
        repl_pcatch,
        text2,
    )
    text2 = re.sub(
        r"\.catch\s*\(\s*\([^)]*\)\s*=>\s*\{([^}]*)\}\s*\)",
        repl_pcatch,
        text2,
    )

    # lsGet/lsSet helpers → TcjErr
    text2 = re.sub(
        r"function\s+lsGet\s*\(\s*key\s*\)\s*\{\s*try\s*\{\s*return\s+localStorage\.getItem\(key\);\s*\}\s*catch\s*\([^)]*\)\s*\{\s*return\s+null;\s*\}\s*\}",
        "function lsGet(key) { return TcjErr.lsGet(key); }",
        text2,
    )
    text2 = re.sub(
        r"function\s+lsSet\s*\(\s*key\s*,\s*value\s*\)\s*\{\s*try\s*\{\s*localStorage\.setItem\(key,\s*value\);\s*\}\s*catch\s*\([^)]*\)\s*\{\s*\}\s*\}",
        "function lsSet(key, value) { TcjErr.lsSet(key, value); }",
        text2,
    )
    text2 = re.sub(
        r"function\s+lsRemove\s*\(\s*key\s*\)\s*\{\s*try\s*\{\s*localStorage\.removeItem\(key\);\s*\}\s*catch\s*\([^)]*\)\s*\{\s*\}\s*\}",
        "function lsRemove(key) { TcjErr.lsRemove(key); }",
        text2,
    )

    return text2, changes


def inject_script_tag(html: str) -> tuple[str, bool]:
    tag = '<script src="lib/tcj-errors.js"></script>'
    if "tcj-errors.js" in html:
        return html, False
    for anchor in (
        '<script src="nav-init.js',
        '<script src="supabase-config.js',
        '<script src="theme-init.js',
    ):
        if anchor in html:
            return html.replace(anchor, tag + "\n" + anchor, 1), True
    return html, False


total_changes = 0
files_changed = 0
injected = 0

for path in sorted(root.rglob("*")):
    if path.suffix not in exts:
        continue
    if any(s in path.parts for s in skip_dirs):
        continue
    rel = str(path.relative_to(root)).replace("\\", "/")
    if rel in skip_files:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    new_text, n = patch_text(text, rel)
    if path.suffix == ".html":
        new_text, inj = inject_script_tag(new_text)
        if inj:
            injected += 1
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        files_changed += 1
        total_changes += n

# dashboard loads supabase-config only — ensure tcj-errors there
dash = root / "dashboard.html"
if dash.exists():
    t = dash.read_text(encoding="utf-8")
    nt, inj = inject_script_tag(t)
    if inj:
        dash.write_text(nt, encoding="utf-8")
        injected += 1

print(json.dumps({"files_changed": files_changed, "catch_patches": total_changes, "script_injected": injected}))
