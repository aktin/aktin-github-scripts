#!/usr/bin/env python3
"""
Block staged data files outside the synthetic-fixture allowlist

The allowlist is a comma separated list of path prefixes in ``--allow``,
``tests/fixtures/`` by default.
"""

from __future__ import annotations

import argparse
import sys

BLOCKED_SUFFIXES = (".csv", ".tsv", ".xls", ".xlsx", ".parquet", ".sql", ".db", ".sqlite", ".log", ".dcm", ".hl7")
DEFAULT_ALLOWLIST = "tests/fixtures/"


def _is_blocked(path: str, allowlist: tuple[str, ...]) -> bool:
  norm = path.replace("\\", "/")
  if norm.startswith(allowlist):
    return False
  return norm.lower().endswith(BLOCKED_SUFFIXES)


def main(argv: list[str]) -> int:
  parser = argparse.ArgumentParser(description="Block staged data files outside the synthetic-fixture allowlist")
  parser.add_argument("--allow", default=DEFAULT_ALLOWLIST, help=f"allowed path prefixes, comma separated (default: {DEFAULT_ALLOWLIST})")
  parser.add_argument("files", nargs="*")
  args = parser.parse_args(argv)
  allowlist = tuple(p.strip() for p in args.allow.split(",") if p.strip())
  blocked = [p for p in args.files if _is_blocked(p, allowlist)]
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
