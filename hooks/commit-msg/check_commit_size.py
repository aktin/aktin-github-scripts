#!/usr/bin/env python3
"""
Reject commits that change more lines than a fixed limit

Counts insertions plus deletions of all staged files via ``git diff --cached --numstat``.
Binary files are ignored because git reports no line counts for them.

Runs as commit-msg hook because the override needs the commit message. A commit
with ``[skip-size]`` in its header is not checked. Meant for changes that cannot
be split, such as a license text or a lock file.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

DEFAULT_MAX_LINES = 200
SKIP_FLAG = "[skip-size]"


def _changed_lines(numstat: str) -> int:
  """Sum insertions and deletions from ``git diff --numstat`` output, skipping binary files."""
  total = 0
  for line in numstat.splitlines():
    added, deleted, *_ = line.split("\t")
    if added == "-":
      continue
    total += int(added) + int(deleted)
  return total


def _git(*args: str) -> str:
  """Run a git command and return its output."""
  return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def _header(message_file: str | None) -> str:
  """Return the first line of the commit message that is neither blank nor a comment."""
  path = Path(message_file or _git("rev-parse", "--git-path", "COMMIT_EDITMSG").strip())
  lines = path.read_text(encoding="utf-8").splitlines()
  return next((line for line in lines if line.strip() and not line.startswith("#")), "")


def main(argv: list[str]) -> int:
  parser = argparse.ArgumentParser(description="Reject commits that change more lines than a fixed limit")
  parser.add_argument("message_file", nargs="?", help="commit message file (default: COMMIT_EDITMSG of the repository)")
  parser.add_argument("--max-lines", type=int, default=DEFAULT_MAX_LINES, help=f"maximum changed lines per commit (default: {DEFAULT_MAX_LINES})")
  args = parser.parse_args(argv)
  if SKIP_FLAG in _header(args.message_file):
    return 0
  changed = _changed_lines(_git("diff", "--cached", "--numstat"))
  if changed <= args.max_lines:
    return 0
  print(f"Refusing to commit {changed} changed lines. Keep every commit <= {args.max_lines} lines.\n", file=sys.stderr)
  print("Large commits are hard to review. Split the change into smaller commits.", file=sys.stderr)
  print(f"A change that cannot be split passes with {SKIP_FLAG} in the commit header.", file=sys.stderr)
  return 1


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
