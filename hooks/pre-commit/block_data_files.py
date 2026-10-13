#!/usr/bin/env python3
"""
Block staged data files outside the synthetic-fixture allowlist
"""

from __future__ import annotations

import sys

BLOCKED_SUFFIXES = (".csv", ".tsv", ".xls", ".xlsx", ".parquet", ".sql", ".db", ".sqlite", ".log", ".dcm", ".hl7")
ALLOWLIST_PREFIX = "tests/fixtures/"


def _is_blocked(path: str) -> bool:
  norm = path.replace("\\", "/")
  if norm.startswith(ALLOWLIST_PREFIX):
    return False
  return norm.lower().endswith(BLOCKED_SUFFIXES)


def main(argv: list[str]) -> int:
  blocked = [p for p in argv if _is_blocked(p)]
  if not blocked:
    return 0
  print("Refusing to commit data files (possible patient data):\n", file=sys.stderr)
  for p in blocked:
    print(f"  - {p}", file=sys.stderr)
  print(
    f"\nData files are blocked outside {ALLOWLIST_PREFIX!r}. Use only synthetic data, and place approved fixtures under that folder.",
    file=sys.stderr,
  )
  return 1


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
