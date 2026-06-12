"""Second pass: catch remaining empty catch blocks."""
import re
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
skip = {"node_modules", ".git", "tests", "fixtures"}
skip_files = {"lib/tcj-errors.js"}

INTENTIONAL = re.compile(
    r"localStorage|lsGet|lsSet|lsRemove|setSelectionRange|revokeObjectURL|"
    r"new\s+URL\s*\(|history\.replaceState|dispatchEvent|clearDraftStorage|"
    r"getElementById\s*\(\s*['\"]tab-|JSON\.parse\s*\(\s*localStorage",
    re.I,
)


def fix_line(line: str, rel: str) -> str:
    if "catch" not in line or "{}" not in line.replace(" ", ""):
        # also match catch(e) { } with space
        if not re.search(r"catch\s*\([^)]+\)\s*\{\s*\}", line):
            return line

    def repl(m):
        var = m.group(1)
        pre = line[: m.start()]
        if INTENTIONAL.search(pre + line[m.end() :]):
            return f"catch({var}) {{ TcjErr.ignore({var}); }}"
        ctx = rel
        if "validate" in pre:
            vm = re.search(r"(validate\w+)", pre)
            if vm:
                ctx = vm.group(1)
        return f"catch({var}) {{ TcjErr.warn('{ctx}', {var}); }}"

    return re.sub(r"catch\s*\(\s*(\w+)\s*\)\s*\{\s*\}", repl, line)


def fix_multiline(text: str, rel: str) -> str:
    def repl_block(m):
        var = m.group(1)
        pre = text[max(0, m.start() - 400) : m.start()]
        if INTENTIONAL.search(pre):
            return f"catch({var}) {{ TcjErr.ignore({var}); }}"
        return f"catch({var}) {{ TcjErr.warn('{rel}', {var}); }}"

    return re.sub(
        r"catch\s*\(\s*(\w+)\s*\)\s*\{\s*\}(?!\s*;?\s*catch)",
        repl_block,
        text,
    )


changed = 0
for path in sorted(root.rglob("*")):
    if path.suffix not in {".html", ".js"}:
        continue
    if any(s in path.parts for s in skip):
        continue
    rel = str(path.relative_to(root)).replace("\\", "/")
    if rel in skip_files:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    lines = [fix_line(ln, rel) for ln in text.split("\n")]
    new = fix_multiline("\n".join(lines), rel)
    if new != text:
        path.write_text(new, encoding="utf-8")
        changed += 1

print(json.dumps({"files_changed": changed}))
