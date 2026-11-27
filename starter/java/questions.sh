# shellcheck shell=bash
# shellcheck disable=SC2154 # name is set by new-repo.sh, which sources this hook
# Asks for the Maven coordinates and derives the Java package from them.
# Sourced by new-repo.sh before the summary. Exports GROUP_ID, ARTIFACT_ID,
# PACKAGE and PACKAGE_PATH as placeholders.
TPL_GROUP_ID=""
until [[ "$TPL_GROUP_ID" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]]; do
  TPL_GROUP_ID=$(ask "Maven groupId" org.aktin "Reverse domain in lowercase, for example org.aktin")
done
TPL_ARTIFACT_ID=""
until [[ "$TPL_ARTIFACT_ID" =~ ^[a-z][a-z0-9-]*$ ]]; do
  TPL_ARTIFACT_ID=$(ask "Maven artifactId" "$(tr '[:upper:]_.' '[:lower:]--' <<<"$name")" "Lowercase letters, digits and hyphens, for example aktin-broker. Also the last part of the Java package")
done
TPL_PACKAGE="$TPL_GROUP_ID.${TPL_ARTIFACT_ID//-/_}"
TPL_PACKAGE_PATH="${TPL_PACKAGE//.//}"
export TPL_GROUP_ID TPL_ARTIFACT_ID TPL_PACKAGE TPL_PACKAGE_PATH
