#!/usr/bin/env python3
"""
Block staged data files outside the synthetic-fixture allowlist

The allowlist is a comma separated list of path prefixes in the environment
variable ``DATA_FILE_ALLOWLIST``. Unset or empty falls back to ``tests/fixtures/``.
"""

from __future__ import annotations

import os
import sys

BLOCKED_SUFFIXES = (".csv", ".tsv", ".xls", ".xlsx", ".parquet", ".sql", ".db", ".sqlite", ".log", ".dcm", ".hl7")
ALLOWLIST_ENV = "DATA_FILE_ALLOWLIST"
DEFAULT_ALLOWLIST = ("tests/fixtures/",)


def _allowlist() -> tuple[str, ...]:
  """Allowed path prefixes from the environment, or the default if none are set."""
  prefixes = tuple(p.strip() for p in os.environ.get(ALLOWLIST_ENV, "").split(",") if p.strip())
  return prefixes or DEFAULT_ALLOWLIST


def _is_blocked(path: str, allowlist: tuple[str, ...]) -> bool:
  norm = path.replace("\\", "/")
  if norm.startswith(allowlist):
    return False
  return norm.lower().endswith(BLOCKED_SUFFIXES)


def main(argv: list[str]) -> int:
  allowlist = _allowlist()
  blocked = [p for p in argv if _is_blocked(p, allowlist)]
  if not blocked:
    return 0
  print("Refusing to commit data files (possible patient data):\n", file=sys.stderr)
  for p in blocked:
    print(f"  - {p}", file=sys.stderr)
  print(
    f"\nData files are blocked outside {', '.join(allowlist)}. Use only synthetic data, and place approved fixtures there.",
    file=sys.stderr,
  )
  return 1


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
