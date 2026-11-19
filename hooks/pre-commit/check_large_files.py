#!/usr/bin/env python3
"""
Reject staged files larger than a fixed size
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

DEFAULT_MAX_KB = 500


def _oversize_bytes(path: str, max_bytes: int) -> int | None:
  try:
    size = Path(path).stat().st_size
  except OSError:
    return None
  return size if size > max_bytes else None


def main(argv: list[str]) -> int:
  parser = argparse.ArgumentParser(description="Reject staged files larger than a fixed size")
  parser.add_argument("--max-kb", type=int, default=DEFAULT_MAX_KB, help=f"maximum file size in KB (default: {DEFAULT_MAX_KB})")
  parser.add_argument("files", nargs="*")
  args = parser.parse_args(argv)
  max_bytes = args.max_kb * 1024
  oversized = [(p, size) for p in args.files if (size := _oversize_bytes(p, max_bytes)) is not None]
  if not oversized:
    return 0
  print(f"Refusing to commit files larger than {args.max_kb} KB:\n", file=sys.stderr)
  for p, size in oversized:
    print(f"  - {p} ({size // 1024} KB)", file=sys.stderr)
  print("\nLarge files are often accidental data dumps; keep data out of the repo.", file=sys.stderr)
  return 1


if __name__ == "__main__":
  raise SystemExit(main(sys.argv[1:]))
