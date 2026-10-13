#!/usr/bin/env python3
"""
Validate a commit message against the EU System Conventional Commit rules:

  <type>(<optional scope>): <subject>

- ``type`` is one of the eight allowed types
- optional ``scope`` in parentheses
- optional ``!`` before the colon marks a breaking change
- ``subject`` starts lowercase and has no trailing period
- every line is at most 100 characters

Merge / revert / fixup! / squash! and empty messages are skipped so the hook
never blocks a merge or interactive rebase.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ALLOWED_TYPES = ("feat", "fix", "docs", "style", "refactor", "perf", "test", "chore")
MAX_LINE_LENGTH = 100

HEADER_RE = re.compile(r"^(?P<type>[a-z]+)(?P<scope>\([^)]+\))?(?P<breaking>!)?: (?P<subject>.+)$")
SKIP_PREFIXES = ("Merge ", "Revert ", "fixup!", "squash!")


def _header_line(message: str) -> str | None:
  """Return the first non-comment, non-blank line, or None if there is none."""
  for line in message.splitlines():
    if line.startswith("#"):
      continue
    if line.strip():
      return line
  return None


def _errors(header: str) -> list[str]:
  problems: list[str] = []
  if len(header) > MAX_LINE_LENGTH:
    problems.append(f"header is {len(header)} chars; keep it <= {MAX_LINE_LENGTH}")
  m = HEADER_RE.match(header)
  if not m:
    problems.append("header must match 'type(scope): subject' (scope optional, single space after the colon)")
    return problems
  if m.group("type") not in ALLOWED_TYPES:
    problems.append(f"type {m.group('type')!r} is not allowed; use one of {', '.join(ALLOWED_TYPES)}")
  subject = m.group("subject")
  if subject[0].isupper():
    problems.append("subject must not start with a capital letter")
  if subject.endswith("."):
    problems.append("subject must not end with a period")
  return problems


def main(argv: list[str]) -> int:
  if not argv:
    print("check_commit_message: no commit message file given", file=sys.stderr)
    return 1
  message = Path(argv[0]).read_text(encoding="utf-8")
  header = _header_line(message)
  if header is None or header.startswith(SKIP_PREFIXES):
    return 0
  problems = _errors(header)
  for i, line in enumerate(message.splitlines(), start=1):
    if line.startswith("#") or line == header:
      continue
    if len(line) > MAX_LINE_LENGTH:
      problems.append(f"line {i} is {len(line)} chars; keep every line <= {MAX_LINE_LENGTH}")
  if not problems:
    return 0
  print(f"Invalid commit message header:\n\n  {header}\n", file=sys.stderr)
  for p in problems:
    print(f"  - {p}", file=sys.stderr)
  print(
    f"\nFormat : <type>(<optional scope>): <subject>\nTypes  : {', '.join(ALLOWED_TYPES)}\nExample: feat(import): add CSV validation for uploads",
    file=sys.stderr,
  )
  return 1


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
