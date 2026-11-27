# shellcheck shell=bash
# Locks the dependencies for the renamed package and installs the git hooks.
# Sourced by new-repo.sh in the new repository.
uv sync
uv run lefthook install
