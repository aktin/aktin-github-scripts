# shellcheck shell=bash
# Refreshes bun.lock for the renamed package, installs the dependencies and
# the git hooks. Sourced by new-repo.sh in the new repository.
bun install
bunx lefthook install
