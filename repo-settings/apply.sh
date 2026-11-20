#!/usr/bin/env bash
# Applies a settings profile to a GitHub repository.
# Usage:    apply.sh <owner/repo> <profile.json>
# Requires: jq and gh, logged in with admin rights on the repository.
set -euo pipefail

repo="$1"
profile="$2"

# Sends one section of the profile as the request body of an API call.
send() {
  local method="$1" path="$2" section="$3"
  jq "$section" "$profile" | gh api -X "$method" "repos/$repo$path" --input - >/dev/null
  echo "ok  $method $path ($section)"
}

# Creates the ruleset, or replaces the existing one of the same name.
apply_ruleset() {
  local ruleset="$1" name id
  name=$(jq -r .name <<<"$ruleset")
  id=$(gh api "repos/$repo/rulesets?includes_parents=false" --paginate \
    --jq ".[] | select(.name == \"$name\") | .id")
  if [ -n "$id" ]; then
    gh api -X PUT "repos/$repo/rulesets/$id" --input - <<<"$ruleset" >/dev/null
  else
    gh api -X POST "repos/$repo/rulesets" --input - <<<"$ruleset" >/dev/null
  fi
  echo "ok  ruleset $name"
}

send PATCH "" .repository
send PUT /actions/permissions .actions_permissions
send PUT /actions/permissions/workflow .workflow_permissions

# Security updates depend on alerts, so the order differs between on and off.
if [ "$(jq -r .dependabot "$profile")" = true ]; then
  gh api -X PUT "repos/$repo/vulnerability-alerts"
  gh api -X PUT "repos/$repo/automated-security-fixes"
# The API rejects turning security updates off while alerts are already off.
elif gh api "repos/$repo/vulnerability-alerts" --silent 2>/dev/null; then
  gh api -X DELETE "repos/$repo/automated-security-fixes"
  gh api -X DELETE "repos/$repo/vulnerability-alerts"
fi
echo "ok  dependabot $(jq -r .dependabot "$profile")"

jq -c '.rulesets[]' "$profile" | while read -r ruleset; do
  apply_ruleset "$ruleset"
done
