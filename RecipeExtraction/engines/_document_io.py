"""Shared helpers for folder-based document extraction."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

from processed_registry import is_file_processed, load_registry, mark_file_processed, save_registry
from tcj_from_text import slugify, split_document_into_recipes, structure_text_to_envelope

from _cookbook_pdf import extract_cookbook_pdf_chunks  # noqa: E402


def _safe_console(text: str) -> str:
    return (text or "").encode("ascii", "replace").decode("ascii")


def file_registry_key(folder: str, path: Path) -> str:
    stat = path.stat()
    return f"{folder}:{path.name}:{stat.st_mtime_ns}:{stat.st_size}"


def refresh_document_file(path: Path, output_dir: Path, *, source_key: str) -> int:
    """Remove prior JSON outputs and registry entry so a book can be re-extracted."""
    registry = load_registry()
    reg_key = file_registry_key(source_key, path)
    processed = registry.get("processed_files", [])
    registry["processed_files"] = [key for key in processed if key != reg_key]
    save_registry(registry)

    prefix = slugify(path.stem)
    removed = 0
    if output_dir.is_dir():
        for json_path in output_dir.glob("*.json"):
            if json_path.name.startswith(prefix):
                json_path.unlink(missing_ok=True)
                removed += 1
    return removed


def read_pdf(path: Path) -> str:
    try:
        from pypdf import PdfReader
    except ImportError as exc:
        raise RuntimeError("Install pypdf: pip install pypdf") from exc
    reader = PdfReader(str(path))
    pages = []
    for page in reader.pages:
        pages.append(page.extract_text() or "")
    return "\n\n".join(pages).strip()


def read_docx(path: Path) -> str:
    try:
        from docx import Document
    except ImportError as exc:
        raise RuntimeError("Install python-docx: pip install python-docx") from exc
    doc = Document(str(path))
    return "\n".join(p.text for p in doc.paragraphs if p.text.strip()).strip()


def read_text_file(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore").strip()


def load_document_text(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix == ".pdf":
        return read_pdf(path)
    if suffix == ".docx":
        return read_docx(path)
    if suffix in {".txt", ".md", ".text"}:
        return read_text_file(path)
    raise ValueError(f"Unsupported file type: {path.suffix}")


def extract_document_folder(
    *,
    input_dir: Path,
    output_dir: Path,
    source_key: str,
    source_label: str,
    import_path: str,
    extensions: set[str],
    limit: int | None = None,
) -> int:
    input_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    registry = load_registry()
    files = sorted(
        p
        for p in input_dir.iterdir()
        if p.is_file() and p.suffix.lower() in extensions and not p.name.upper().startswith("README")
    )
    if limit:
        files = files[:limit]

    saved = 0
    for path in files:
        reg_key = file_registry_key(source_key, path)
        if is_file_processed(registry, reg_key):
            print(f"  [SKIP] already processed: {path.name}")
            continue
        print(f"  [*] Reading {path.name}")
        try:
            chunks = extract_cookbook_pdf_chunks(path) if path.suffix.lower() == ".pdf" else None
            if chunks is None:
                text = load_document_text(path)
                if len(text) < 80:
                    print(f"  [SKIP] too little text: {path.name}")
                    continue
                chunks = [{"title": c["title"], "body": c["body"], "section": "", "book_parser": "document-generic"} for c in split_document_into_recipes(text)]
            else:
                print(f"  [*] Cookbook layout detected ({len(chunks)} recipe(s) found)")
                for chunk in chunks:
                    chunk["book_parser"] = "cookbook-serves-v1"
        except Exception as exc:
            print(f"  [!] Failed {path.name}: {exc}")
            continue
        if not chunks:
            print(f"  [SKIP] no valid recipes in {path.name}")
            continue

        file_saved = 0
        for idx, chunk in enumerate(chunks, 1):
            source_id = f"tcj://{source_key}/{path.stem}#{idx}"
            envelope = structure_text_to_envelope(
                chunk["body"],
                source_id=source_id,
                source_label=source_label,
                credit_name=path.stem.replace("-", " ").replace("_", " "),
                credit_url=source_id,
                import_path=import_path,
                title_hint=chunk["title"],
            )
            if chunk.get("section") and envelope.get("structured"):
                section = chunk["section"].lower()
                category_map = {
                    "vegetarian": "Garden & Earth",
                    "seafood": "Ocean & River",
                    "poultry": "Meat & Fire",
                    "meat": "Meat & Fire",
                    "desserts": "Sweet Serenades",
                }
                mapped = category_map.get(section)
                if mapped:
                    envelope["structured"]["category"] = mapped
                book = path.stem.replace("-", " ").replace("_", " ")
                parsed_intro = envelope["structured"].get("introduction") or ""
                if parsed_intro.startswith("Imported from "):
                    parsed_intro = ""
                envelope["structured"]["introduction"] = (
                    f"From {book} ({chunk['section']} section). {parsed_intro}".strip().rstrip(".")
                    + "."
                )
                envelope["structured"]["credit_name"] = book
                serves_match = re.search(r"^Serves\s+(\d+)", chunk["body"], re.I | re.M)
                if serves_match:
                    envelope["structured"]["servings"] = max(1, int(serves_match.group(1)))
            if not envelope.get("ok"):
                print(
                    f"    [SKIP] {_safe_console(chunk['title'][:60])} "
                    f"({envelope.get('reason') or 'quality gate'})"
                )
                continue
            slug = slugify(chunk["title"])
            if len(chunks) > 1:
                slug = f"{slugify(path.stem)}-{idx}-{slug}"[:90]
            out_path = output_dir / f"{slug}.json"
            envelope["source_file"] = path.name
            if chunk.get("book_parser"):
                envelope["book_parser"] = chunk["book_parser"]
            out_path.write_text(json.dumps(envelope, indent=2, ensure_ascii=False), encoding="utf-8")
            file_saved += 1
            saved += 1
            print(f"    [OK] {_safe_console(out_path.name)}")

        if file_saved:
            mark_file_processed(registry, reg_key)
            save_registry(registry)
        else:
            print(f"  [SKIP] no valid recipes in {path.name}")

    return saved
