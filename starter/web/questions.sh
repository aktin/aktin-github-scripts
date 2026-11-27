# shellcheck shell=bash
# shellcheck disable=SC2154 # name is set by new-repo.sh, which sources this hook
# Asks for the npm package name of the workspace root. Sourced by new-repo.sh
# before the summary. Exports PACKAGE_NAME as a placeholder.
TPL_PACKAGE_NAME=""
until [[ "$TPL_PACKAGE_NAME" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; do
  TPL_PACKAGE_NAME=$(ask "Package name" "$(tr '[:upper:]' '[:lower:]' <<<"$name")" "Name in package.json. Lowercase letters, digits, dots, hyphens and underscores")
done
export TPL_PACKAGE_NAME
