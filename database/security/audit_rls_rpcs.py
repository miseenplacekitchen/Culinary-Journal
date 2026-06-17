#!/usr/bin/env python3
"""Scan full-setup.sql for SECURITY DEFINER functions and classify auth guards."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FULL_SETUP = ROOT / "database" / "full-setup.sql"


def split_functions(sql: str) -> list[tuple[str, str]]:
    pattern = re.compile(
        r"CREATE (?:OR REPLACE )?FUNCTION (?:public\.)?(\w+)\s*\(",
        re.IGNORECASE,
    )
    matches = list(pattern.finditer(sql))
    out: list[tuple[str, str]] = []
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(sql)
        block = sql[start:end]
        if "SECURITY DEFINER" not in block.upper():
            continue
        out.append((m.group(1), block))
    return out


def classify(name: str, body: str) -> str:
    upper = body.upper()
    if "IS_ADMIN()" in upper or "NOT IS_ADMIN()" in upper:
        if name == "is_admin":
            return "helper"
        return "admin_guard"
    if "AUTH.UID()" in upper:
        if "AUTH.UID() IS NULL" in upper or "USER_ID = AUTH.UID()" in upper.replace(" ", ""):
            return "user_scoped"
        return "uses_uid"
    if name.startswith("get_") or name.startswith("search_"):
        return "public_read_review"
    return "NO_AUTH_CHECK"


def main() -> int:
    if not FULL_SETUP.exists():
        print(f"Missing {FULL_SETUP}", file=sys.stderr)
        return 1
    sql = FULL_SETUP.read_text(encoding="utf-8")
    fns = split_functions(sql)
    counts: dict[str, list[str]] = {}
    for name, body in fns:
        cat = classify(name, body)
        counts.setdefault(cat, []).append(name)

    print(f"SECURITY DEFINER functions in full-setup.sql: {len(fns)}\n")
    for cat in sorted(counts):
        names = counts[cat]
        print(f"  {cat}: {len(names)}")
        if cat == "NO_AUTH_CHECK":
            for n in names:
                print(f"    - {n}")
    print("\nSee database/security/SECURITY-AUDIT.md for severity and live-only gaps.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
