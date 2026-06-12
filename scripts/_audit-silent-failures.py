"""Scan HTML/JS for silent failure patterns."""
import re
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
exts = {".html", ".js"}
skip_dirs = {"node_modules", ".git", "tests"}

patterns = {
    "empty_catch": re.compile(r"catch\s*\([^)]*\)\s*\{\s*\}", re.M),
    "empty_promise_catch": re.compile(r"\.catch\s*\(\s*function\s*\([^)]*\)\s*\{\s*\}\s*\)", re.M),
    "empty_arrow_catch": re.compile(r"\.catch\s*\(\s*\([^)]*\)\s*=>\s*\{\s*\}\s*\)", re.M),
    "return_null": re.compile(r"catch\s*\([^)]*\)\s*\{\s*return\s+null\s*;?\s*\}", re.M),
    "return_array": re.compile(r"catch\s*\([^)]*\)\s*\{\s*return\s+\[\]\s*;?\s*\}", re.M),
    "return_false": re.compile(r"catch\s*\([^)]*\)\s*\{\s*return\s+false\s*;?\s*\}", re.M),
}

catch_block = re.compile(r"catch\s*\([^)]*\)\s*\{", re.M)
feedback_re = re.compile(
    r"console\.|TcjErr\.(warn|rpcFallback|toast|bannerOnce|sectionError|ls)|alert\(|showError|"
    r"showImportStatus|showMsg|dashSectionError|show\(['\"]error|innerHTML.*[Ee]rror|"
    r"textContent.*[Ee]rror|throw\s|Could not|Failed|status\.|display\s*=\s*['\"]block|"
    r"\berr\s*\(|alert\s*\(",
    re.I,
)
intentional_re = re.compile(r"TcjErr\.ignore", re.I)

def has_feedback_after(text, start):
    """Rough scan of catch body (next 500 chars)."""
    chunk = text[start : start + 500]
    end = chunk.find("}")
    body = chunk[:end] if end != -1 else chunk
    body = re.sub(r"//[^\n]*", "", body)
    return bool(feedback_re.search(body))

files = []
for path in sorted(root.rglob("*")):
    if path.suffix not in exts:
        continue
    if any(s in path.parts for s in skip_dirs):
        continue
    if "fixtures" in path.parts:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    counts = {k: len(p.findall(text)) for k, p in patterns.items()}
    silent_blocks = 0
    for m in catch_block.finditer(text):
        chunk = text[m.end() : m.end() + 500]
        end = chunk.find("}")
        body = chunk[:end] if end != -1 else chunk
        if intentional_re.search(body):
            continue
        if not has_feedback_after(text, m.end()):
            silent_blocks += 1
    total = sum(counts.values())
    if total > 0 or silent_blocks > 0:
        files.append({
            "file": str(path.relative_to(root)).replace("\\", "/"),
            **counts,
            "silent_no_feedback": silent_blocks,
            "score": counts["empty_catch"] + counts["empty_promise_catch"] + counts["empty_arrow_catch"]
            + counts["return_null"] + counts["return_array"] + silent_blocks,
        })

files.sort(key=lambda x: x["score"], reverse=True)
grand = {k: sum(f[k] for f in files) for k in patterns}
grand["silent_no_feedback"] = sum(f["silent_no_feedback"] for f in files)
grand["files_affected"] = len(files)

out = root / "scripts" / "silent-failures-report.json"
out.write_text(json.dumps({"grand": grand, "files": files}, indent=2), encoding="utf-8")
print(json.dumps(grand, indent=2))
for f in files[:50]:
    if f["score"] < 1:
        continue
    print(
        f"{f['score']:3d}  {f['file']}  "
        f"empty={f['empty_catch']} ret[]={f['return_array']} retnull={f['return_null']} "
        f"pcatch={f['empty_promise_catch']+f['empty_arrow_catch']} no_fb={f['silent_no_feedback']}"
    )
