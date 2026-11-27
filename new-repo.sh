#!/usr/bin/env bash
# Creates a new AKTIN repository from a starter and applies a settings profile.
# Usage:    new-repo.sh
# Requires: git, jq, gh logged in, and the tools the setup.sh of the stack calls.
#
# A stack is a folder in starter/. Its files are copied over those of its
# layers: common, then each prefix of the stack name split at "-". The stack
# python-flask copies common, python and python-flask in this order.
# In a layer, profile/<profile>/ holds files for that profile only and
# setup.sh runs in the new repository after the copy. Neither is copied.
# Text between profile:<profile>:start and profile:<profile>:end lines stays
# only for that profile. {{NAME}} placeholders are filled in contents and paths.
set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
starters="$root/starter"
settings="$root/repo-settings"

# Asks a question and prints the answer, or the default when it is empty.
ask() {
  local answer
  read -rp "$1${2:+ [$2]}: " answer
  echo "${answer:-${2:-}}"
}

# Asks until the answer is not empty and prints it.
ask_required() {
  local answer=""
  while [ -z "$answer" ]; do read -rp "$1: " answer; done
  echo "$answer"
}

# Lets the user pick one of the options and prints its index, counted from 0.
choose() {
  local PS3="$1: " choice
  shift
  select choice in "$@"; do
    [ -n "$choice" ] && { echo $((REPLY - 1)); return; }
  done
}

# Prints the layers of a stack that exist, from general to specific.
layers() {
  local layer="" part parts
  echo common
  IFS=- read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    layer="${layer:+$layer-}$part"
    if [ -d "$starters/$layer" ]; then echo "$layer"; fi
  done
}

# Fills the placeholders and keeps the profile blocks of the chosen profile.
# Reads stdin, writes stdout, takes the values from the exported TPL_ vars.
fill() {
  awk -v profile="$profile" '
    BEGIN { for (k in ENVIRON) if (k ~ /^TPL_/) vars[substr(k, 5)] = ENVIRON[k] }
    match($0, /profile:[a-z-]+:(start|end)/) {
      split(substr($0, RSTART, RLENGTH), marker, ":")
      skip = marker[3] == "start" && marker[2] != profile
      next
    }
    skip { next }
    {
      for (k in vars)
        while ((i = index($0, "{{" k "}}")) > 0)
          $0 = substr($0, 1, i - 1) vars[k] substr($0, i + length(k) + 4)
      print
    }'
}

# Copies the files of one layer, without its profile folder and setup.sh.
copy_layer() {
  local src="$starters/$1"
  (cd "$src" && tar -c --exclude=./profile --exclude=./setup.sh .) | tar -x -C "$dest"
  if [ -d "$src/profile/$profile" ]; then cp -a "$src/profile/$profile/." "$dest/"; fi
}

# Fills the placeholders in all file contents, keeping the file modes, then
# in file and folder names.
render() {
  local file path
  grep -rlIE '\{\{[A-Z_]+\}\}|profile:[a-z-]+:(start|end)' "$dest" | while read -r file; do
    fill <"$file" >"$file.tmp"
    cat "$file.tmp" >"$file"
    rm "$file.tmp"
  done
  find "$dest" -depth -name '*{{*}}*' | while read -r path; do
    mv "$path" "$(dirname "$path")/$(basename "$path" | fill)"
  done
}

for tool in git jq gh; do
  command -v "$tool" >/dev/null || { echo "$tool is missing" >&2; exit 1; }
done

mapfile -t stacks < <(find "$starters" -mindepth 1 -maxdepth 1 -type d ! -name common -printf '%f\n' | sort)
mapfile -t profiles < <(find "$settings" -name '*.json' ! -name template.json -printf '%f\n' | sed 's/\.json$//' | sort)
profile_labels=()
for p in "${profiles[@]}"; do profile_labels+=("$(jq -r .description "$settings/$p.json")"); done

me=$(gh api user --jq .login)
echo "The repository is created on GitHub at github.com/<account>/<name> and cloned into $PWD/<name>."
owner=$(ask "GitHub account, an organization or your user" aktin)
name=$(ask_required "Repository name, also the project and package name")
stack=${stacks[$(choose "Stack" "${stacks[@]}")]}
profile=${profiles[$(choose "Settings profile" "${profile_labels[@]}")]}
visibilities=(public private)
visibility=${visibilities[$(choose "Visibility. Private needs paid GitHub features" "${visibilities[@]}")]}
description=$(ask_required "GitHub description, one line shown on the repository page and in the README")
read -ra others <<<"$(ask "Code owners besides @$me, who must approve pull requests into main. Separate by spaces, for example @alice @aktin/devs. Empty for none")"
codeowners="@$me"
for other in "${others[@]}"; do codeowners+=" @${other#@}"; done
author=$(ask "Author name in the package metadata, for example pyproject.toml" "$(git config user.name || true)")

dest="$PWD/$name"
[ ! -e "$dest" ] || { echo "$dest already exists" >&2; exit 1; }

module=$(tr '[:upper:]' '[:lower:]' <<<"$name" | tr '.-' '__')
export TPL_PROJECT_NAME="$name" TPL_REPO_SLUG="$owner/$name" TPL_DESCRIPTION="$description" \
  TPL_OWNER="$me" TPL_CODEOWNERS="$codeowners" TPL_AUTHOR="$author" TPL_PROFILE="$profile" TPL_MODULE="$module"

mkdir "$dest"
mapfile -t stack_layers < <(layers "$stack")
for layer in "${stack_layers[@]}"; do copy_layer "$layer"; done
render

git -C "$dest" init -q -b main
for layer in "${stack_layers[@]}"; do
  if [ -f "$starters/$layer/setup.sh" ]; then (cd "$dest" && bash "$starters/$layer/setup.sh"); fi
done
git -C "$dest" add -A
# The first commit holds the whole starter, so it skips the commit size hook.
git -C "$dest" commit -S -q -m "chore: create the repository from the $stack starter [skip-size]"

gh repo create "$owner/$name" "--$visibility" --description "$description" --source "$dest" --push

# Branches other than main that the profile protects must exist before its
# rulesets block direct pushes.
jq -r '.rulesets[] | select(.target == "branch") | .conditions.ref_name.include[]
  | sub("^refs/heads/"; "") | select(. != "main")' "$settings/$profile.json" | while read -r branch; do
  git -C "$dest" push -q origin "main:$branch"
done

"$settings/apply.sh" "$owner/$name" "$settings/$profile.json"
echo "Created $owner/$name in $dest. Do the manual steps in starter/README.md section 4."
