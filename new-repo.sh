#!/usr/bin/env bash
# Creates a new AKTIN repository from a starter and applies a settings profile.
# Usage:    new-repo.sh [--local]
#           --local builds the repository only locally, logs the GitHub steps
#           as skipped and copies the profile it would apply to repo-settings/.
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

# Colors only on a terminal and only when NO_COLOR is not set.
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  bold=$'\e[1m' dim=$'\e[2m' red=$'\e[31m' green=$'\e[32m' cyan=$'\e[36m' reset=$'\e[0m'
else
  bold="" dim="" red="" green="" cyan="" reset=""
fi

# All output for the user goes to stderr, stdout carries the answers.
say() { printf '%s\n' "$*" >&2; }
step() { say "" "${bold}${cyan}▸ $*${reset}"; }
done_step() { say "${green}✔${reset} $*"; }
fail() { say "${red}✘ $*${reset}"; exit 1; }
skipped() { say "${dim}↷ $* (skipped, --local)${reset}"; }

case "${1:-}" in
  "") local_only=false ;;
  --local) local_only=true ;;
  *) fail "Usage: new-repo.sh [--local]" ;;
esac

# Prints a question with an optional hint line below it.
question() {
  say ""
  say "${bold}${cyan}?${reset} ${bold}$1${reset}"
  if [ -n "${2:-}" ]; then say "  ${dim}$2${reset}"; fi
}

# Asks a question and prints the answer, or the default when it is empty.
ask() {
  local answer
  question "$1" "${3:-}"
  read -rp "  ${2:+${dim}[$2]${reset} }› " answer
  echo "${answer:-${2:-}}"
}

# Asks until the answer is not empty and prints it.
ask_required() {
  local answer=""
  question "$1" "${2:-}"
  while [ -z "$answer" ]; do read -rp "  › " answer; done
  echo "$answer"
}

# Lets the user pick one of the options and prints its index, counted from 0.
choose() {
  local title="$1" i answer
  shift
  question "$title"
  i=1
  for option in "$@"; do say "  ${cyan}$i)${reset} $option"; i=$((i + 1)); done
  while true; do
    read -rp "  › " answer
    if [[ "$answer" =~ ^[0-9]+$ ]] && [ "$answer" -ge 1 ] && [ "$answer" -le $# ]; then
      echo $((answer - 1))
      return
    fi
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
  command -v "$tool" >/dev/null || fail "$tool is missing"
done

mapfile -t stacks < <(find "$starters" -mindepth 1 -maxdepth 1 -type d ! -name common -printf '%f\n' | sort)
mapfile -t profiles < <(find "$settings" -name '*.json' ! -name template.json -printf '%f\n' | sed 's/\.json$//' | sort)
profile_labels=()
for p in "${profiles[@]}"; do profile_labels+=("$(jq -r .description "$settings/$p.json")"); done

me=$(gh api user --jq .login)
say "${bold}New AKTIN repository${reset}"
say "${dim}Creates github.com/<account>/<name> and clones it into $PWD/<name>.${reset}"

owner=$(ask "GitHub account" aktin "Organization or user the repository belongs to")
name=$(ask_required "Repository name" "Also the local folder, the project name and the package name")
dest="$PWD/$name"
[ ! -e "$dest" ] || fail "$dest already exists"
stack=${stacks[$(choose "Stack" "${stacks[@]}")]}
profile=${profiles[$(choose "Settings profile" "${profile_labels[@]}")]}
visibilities=(public private)
visibility=${visibilities[$(choose "Visibility" "public" "private (needs paid GitHub features)")]}
description=$(ask_required "GitHub description" "One line, shown on the repository page and in the README")
read -ra others <<<"$(ask "Code owners besides @$me" "" "Must approve pull requests into main. Separate by spaces, for example @alice @aktin/devs. Empty for none")"
codeowners="@$me"
for other in "${others[@]}"; do codeowners+=" @${other#@}"; done
author=$(ask "Author" "$(git config user.name || true)" "Your name in the package metadata, for example pyproject.toml")

say ""
say "${bold}Summary${reset}"
say "  Repository   github.com/$owner/$name ($visibility)"
say "  Local folder $dest"
if $local_only; then say "  ${bold}Mode         --local, nothing is created on GitHub${reset}"; fi
say "  Stack        $stack"
say "  Profile      $profile"
say "  Code owners  $codeowners"
say "  Author       $author"
say "  Description  $description"
read -rp "  Create it? [y/N] › " confirm
[[ "$confirm" =~ ^[yY]$ ]] || fail "Cancelled, nothing was created"

module=$(tr '[:upper:]' '[:lower:]' <<<"$name" | tr '.-' '__')
export TPL_PROJECT_NAME="$name" TPL_REPO_SLUG="$owner/$name" TPL_DESCRIPTION="$description" \
  TPL_OWNER="$me" TPL_CODEOWNERS="$codeowners" TPL_AUTHOR="$author" TPL_PROFILE="$profile" TPL_MODULE="$module"

step "Copying the starter files"
mkdir "$dest"
mapfile -t stack_layers < <(layers "$stack")
for layer in "${stack_layers[@]}"; do copy_layer "$layer"; done
render
done_step "Layers ${stack_layers[*]}"

step "Setting up the stack"
git -C "$dest" init -q -b main
for layer in "${stack_layers[@]}"; do
  if [ -f "$starters/$layer/setup.sh" ]; then (cd "$dest" && bash "$starters/$layer/setup.sh"); fi
done
done_step "Dependencies and git hooks installed"

step "First commit"
git -C "$dest" add -A
# The first commit holds the whole starter, so it skips the commit size hook.
git -C "$dest" commit -S -q -m "chore: create the repository from the $stack starter [skip-size]"

done_step "Signed commit on main"

step "Creating github.com/$owner/$name"
if $local_only; then
  skipped "gh repo create $owner/$name --$visibility --push"
else
  gh repo create "$owner/$name" "--$visibility" --description "$description" --source "$dest" --push
fi

# Branches other than main that the profile protects must exist before its
# rulesets block direct pushes.
jq -r '.rulesets[] | select(.target == "branch") | .conditions.ref_name.include[]
  | sub("^refs/heads/"; "") | select(. != "main")' "$settings/$profile.json" | while read -r branch; do
  if $local_only; then
    git -C "$dest" branch "$branch" main
    skipped "Push of branch $branch, created locally"
  else
    git -C "$dest" push -q origin "main:$branch"
    done_step "Branch $branch"
  fi
done

step "Applying the settings profile $profile"
if $local_only; then
  mkdir "$dest/repo-settings"
  cp "$settings/$profile.json" "$dest/repo-settings/"
  skipped "apply.sh, the profile is in $dest/repo-settings/$profile.json"
  say ""
  say "${green}${bold}✔ Built $name locally${reset} in $dest"
else
  "$settings/apply.sh" "$owner/$name" "$settings/$profile.json"
  say ""
  say "${green}${bold}✔ Created github.com/$owner/$name${reset} in $dest"
  say "  Next: the manual steps in section 4 of starter/README.md"
fi
