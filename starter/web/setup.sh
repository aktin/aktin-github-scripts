# shellcheck shell=bash
# Refreshes bun.lock for the renamed package and installs the dependencies.
# The prepare script in package.json installs the git hooks with lefthook.
# Sourced by new-repo.sh in the new repository.
bun install
