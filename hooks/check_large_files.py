#!/usr/bin/env python3
"""
Reject staged files larger than a fixed size
"""

from __future__ import annotations

import sys
from pathlib import Path

MAX_KB = 500
MAX_BYTES = MAX_KB * 1024


def _oversize_bytes(path: str) -> int | None:
  try:
    size = Path(path).stat().st_size
  except OSError:
    return None
  return size if size > MAX_BYTES else None


def main(argv: list[str]) -> int:
  oversized = [(p, size) for p in argv if (size := _oversize_bytes(p)) is not None]
  if not oversized:
    return 0
  print(f"Refusing to commit files larger than {MAX_KB} KB:\n", file=sys.stderr)
  for p, size in oversized:
    print(f"  - {p} ({size // 1024} KB)", file=sys.stderr)
  print("\nLarge files are often accidental data dumps; keep data out of the repo.", file=sys.stderr)
  return 1


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
