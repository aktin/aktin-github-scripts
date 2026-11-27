#!/usr/bin/env bash
# Applies a settings profile to a GitHub repository.
# Usage:    apply.sh <owner/repo> <profile.json>
# Requires: jq and gh, logged in with admin rights on the repository.
set -euo pipefail

repo="$1"
profile="$2"

# Sends one section of the profile as the request body of an API call.
# A section the profile does not contain is skipped.
send() {
  local method="$1" path="$2" section="$3"
  jq -e "$section != null" "$profile" >/dev/null || return 0
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
send PUT /actions/permissions/fork-pr-contributor-approval .fork_pr_approval
send PUT /actions/permissions/artifact-and-log-retention .artifact_retention
send PATCH /code-scanning/default-setup .code_scanning_default_setup

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

case "$(jq -r .private_vulnerability_reporting "$profile")" in
  true)  gh api -X PUT "repos/$repo/private-vulnerability-reporting" && echo "ok  private vulnerability reporting on" ;;
  false) gh api -X DELETE "repos/$repo/private-vulnerability-reporting" && echo "ok  private vulnerability reporting off" ;;
esac

jq -c '.rulesets[]' "$profile" | while read -r ruleset; do
  apply_ruleset "$ruleset"
done

# Deletes the listed labels that exist and creates or updates the others.
existing=$(gh label list -R "$repo" --limit 1000 --json name --jq '.[].name')
jq -r '.labels.delete[]?' "$profile" | while read -r label; do
  if grep -qxF "$label" <<<"$existing"; then gh label delete "$label" -R "$repo" --yes >/dev/null; fi
  echo "ok  label $label deleted"
done
jq -c '.labels.create[]?' "$profile" | while read -r label; do
  gh label create "$(jq -r .name <<<"$label")" -R "$repo" --force \
    --color "$(jq -r .color <<<"$label")" --description "$(jq -r .description <<<"$label")"
  echo "ok  label $(jq -r .name <<<"$label")"
done

# A profile without the key leaves immutable releases untouched.
case "$(jq -r .immutable_releases "$profile")" in
  true)  gh api -X PUT "repos/$repo/immutable-releases" && echo "ok  immutable releases on" ;;
  false) gh api -X DELETE "repos/$repo/immutable-releases" && echo "ok  immutable releases off" ;;
esac
