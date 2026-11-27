#!/usr/bin/env bash
# Runs in the root of a new repository after new-repo.sh copied the files.
# Locks the dependencies for the renamed package and installs the git hooks.
set -euo pipefail

uv sync
uv run lefthook install
