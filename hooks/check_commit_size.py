#!/usr/bin/env python3
"""
Reject commits that change more lines than a fixed limit

Counts insertions plus deletions of all staged files via ``git diff --cached --numstat``.
Binary files are ignored because git reports no line counts for them.
"""

from __future__ import annotations

import argparse
import subprocess
import sys

DEFAULT_MAX_LINES = 200


def _changed_lines(numstat: str) -> int:
  """Sum insertions and deletions from ``git diff --numstat`` output, skipping binary files."""
  total = 0
  for line in numstat.splitlines():
    added, deleted, *_ = line.split("\t")
    if added == "-":
      continue
    total += int(added) + int(deleted)
  return total


def main(argv: list[str]) -> int:
  parser = argparse.ArgumentParser(description="Reject commits that change more lines than a fixed limit")
  parser.add_argument("--max-lines", type=int, default=DEFAULT_MAX_LINES, help=f"maximum changed lines per commit (default: {DEFAULT_MAX_LINES})")
  args = parser.parse_args(argv)
  numstat = subprocess.run(["git", "diff", "--cached", "--numstat"], capture_output=True, text=True, check=True).stdout
  changed = _changed_lines(numstat)
  if changed <= args.max_lines:
    return 0
  print(f"Refusing to commit {changed} changed lines. Keep every commit <= {args.max_lines} lines.\n", file=sys.stderr)
  print("Large commits are hard to review. Split the change into smaller commits.", file=sys.stderr)
  return 1


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
