#!/usr/bin/env python3
"""
Betty's admin routine — polish anything still messy, print inbox summary.

Run after imports (or weekly). Safe to re-run anytime.

  python admin_routine.py
  python admin_routine.py --dry-run
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent


def _configure_stdio_utf8() -> None:
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if callable(reconfigure):
            try:
                reconfigure(encoding="utf-8", errors="replace")
            except (OSError, ValueError):
                pass


def run_py(script: str, args: list[str]) -> int:
    cmd = [sys.executable, str(BASE / script), *args]
    print(f"\n>> {' '.join(cmd)}")
    return subprocess.run(cmd, cwd=str(BASE), env=os.environ.copy()).returncode


def inbox_summary() -> None:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        return
    try:
        from supabase import create_client

        sb = create_client(url, key)
        pending = sb.table("submitted_recipes").select("id", count="exact").eq("status", "pending").execute()
        unpolished = (
            sb.table("submitted_recipes")
            .select("id", count="exact")
            .eq("status", "pending")
            .eq("procedure_rewritten", False)
            .execute()
        )
        total = pending.count if pending.count is not None else len(pending.data or [])
        need_polish = unpolished.count if unpolished.count is not None else len(unpolished.data or [])
        print("\n" + "=" * 60)
        print("ADMIN INBOX")
        print("=" * 60)
        print(f"  Pending recipes:        {total}")
        print(f"  Awaiting mechanical polish: {need_polish}")
        print(f"  Ready for your review:  {max(0, total - need_polish)}")
        print("\nNext: Admin dashboard → Recipes → Pending")
        print("  • Open a recipe, scroll down → Approve or Reject")
        print("  • Skip obvious junk; bulk-approve good ones")
        print("  • Images optional for book imports (add later if you want)")
        print("=" * 60)
    except Exception as exc:  # noqa: BLE001
        print(f"Could not read inbox counts: {exc}", file=sys.stderr)


def main() -> int:
    _configure_stdio_utf8()
    parser = argparse.ArgumentParser(description="TCJ admin routine — polish pending + summary")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--skip-polish", action="store_true")
    args = parser.parse_args()

    if not os.environ.get("SUPABASE_URL") or not os.environ.get("SUPABASE_SERVICE_ROLE_KEY"):
        print("Load setup-env.ps1 first (Supabase keys).", file=sys.stderr)
        return 1

    print("=" * 60)
    print("TCJ ADMIN ROUTINE")
    print("=" * 60)

    failures = 0
    if not args.skip_polish:
        polish_args = ["--limit", str(args.limit or 50)]
        if args.dry_run:
            polish_args.append("--dry-run")
        code = run_py("polish_mechanical.py", polish_args)
        if code != 0:
            failures += code

    if not args.dry_run:
        run_py("fix_pending_titles.py", ["--all"])

    inbox_summary()

    if failures:
        print("\nSome recipes could not be polished. Check errors above.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
