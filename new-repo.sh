#!/usr/bin/env bash
# Creates a new AKTIN repository from a starter and applies a settings profile.
# Usage:    new-repo.sh [--local]
#           --local builds the repository only locally, logs the GitHub steps
#           as skipped and copies the profile it would apply to repo-settings/.
# Requires: git, jq, gh logged in, a git signing key, and what the
#           requirements.sh of the stack layers checks.
#
# A stack is a folder in starter/. Its files are copied over those of its
# layers: common, then each prefix of the stack name split at "-". The stack
# python-flask copies common, python and python-flask in this order.
# In a layer, profile/<profile>/ holds files for that profile only. These
# optional hooks are sourced, so they can use say, ask, need and fail:
#   requirements.sh  checks the tools of the layer, before anything is created
#   version.sh       asks for the language version and sets it, in the new repository
#   setup.sh         installs dependencies and git hooks, in the new repository
# Neither profile/ nor a hook is copied.
# Text between profile:<profile>:start and profile:<profile>:end lines stays
# only for that profile. {{NAME}} placeholders are filled in contents and paths.
#
# The answers and the finished steps are kept in .<name>.new-repo next to the
# new folder. Run the script again with the same name to resume after an
# error. The file is removed when all steps are done.
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

# Fails when one of the tools is not on PATH.
need() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null || fail "$tool is missing, install it first"
  done
}

# Sources a hook of every layer that has it, in a subshell inside the folder.
run_hooks() {
  local hook="$1" dir="$2" layer
  for layer in "${stack_layers[@]}"; do
    # shellcheck source=/dev/null
    if [ -f "$starters/$layer/$hook" ]; then (cd "$dir" && source "$starters/$layer/$hook"); fi
  done
}

# Copies the files of one layer, without its profile folder and hooks.
copy_layer() {
  local src="$starters/$1"
  (cd "$src" && tar -c --exclude=./profile --exclude=./requirements.sh --exclude=./version.sh --exclude=./setup.sh .) |
    tar -x -C "$dest"
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

# Runs a step unless the state file marks it as done, then marks it.
run_step() {
  local id="$1" title="$2"
  if grep -qx "done $id" "$state"; then
    say "${dim}✔ $title (done in an earlier run)${reset}"
    return
  fi
  step "$title"
  "step_$id"
  echo "done $id" >>"$state"
}

step_files() {
  rm -rf "$dest"
  mkdir "$dest"
  for layer in "${stack_layers[@]}"; do copy_layer "$layer"; done
  render
  done_step "Layers ${stack_layers[*]}"
}

step_version() {
  run_hooks version.sh "$dest"
  done_step "Versions set"
}

step_setup() {
  git -C "$dest" init -q -b main
  run_hooks setup.sh "$dest"
  done_step "Dependencies and git hooks installed"
}

step_commit() {
  git -C "$dest" add -A
  # The first commit holds the whole starter, so it skips the commit size hook.
  git -C "$dest" commit -S -q -m "chore: create the repository from the $stack starter [skip-size]"
  done_step "Signed commit on main"
}

step_github() {
  local field=url
  if $local_only; then
    skipped "gh repo create $owner/$name --public and push of main"
    return
  fi
  if ! gh repo view "$owner/$name" >/dev/null 2>&1; then
    gh repo create "$owner/$name" --public --description "$description" >/dev/null
  fi
  if [ "$(gh config get git_protocol)" = ssh ]; then field=sshUrl; fi
  if ! git -C "$dest" remote get-url origin >/dev/null 2>&1; then
    git -C "$dest" remote add origin "$(gh repo view "$owner/$name" --json "$field" --jq ".$field")"
  fi
  git -C "$dest" push -q -u origin main
  done_step "github.com/$owner/$name with main"
}

# Branches other than main that the profile protects must exist before its
# rulesets block direct pushes.
step_branches() {
  local branch
  jq -r '.rulesets[] | select(.target == "branch") | .conditions.ref_name.include[]
    | sub("^refs/heads/"; "") | select(. != "main")' "$settings/$profile.json" | while read -r branch; do
    if $local_only; then
      git -C "$dest" branch -f "$branch" main
      skipped "Push of branch $branch, created locally"
    else
      git -C "$dest" push -q origin "main:$branch"
      done_step "Branch $branch"
    fi
  done
}

step_settings() {
  if $local_only; then
    mkdir -p "$dest/repo-settings"
    cp "$settings/$profile.json" "$dest/repo-settings/"
    skipped "apply.sh, the profile is in $dest/repo-settings/$profile.json"
  else
    "$settings/apply.sh" "$owner/$name" "$settings/$profile.json"
  fi
}

need git jq gh tar awk
gh auth status >/dev/null 2>&1 || fail "gh is not logged in, run gh auth login"
[ -n "$(git config --get user.signingkey)" ] || fail "No git signing key, set user.signingkey as described in starter/README.md section 1"

mapfile -t stacks < <(find "$starters" -mindepth 1 -maxdepth 1 -type d ! -name common -printf '%f\n' | sort)
mapfile -t profiles < <(find "$settings" -name '*.json' ! -name template.json -printf '%f\n' | sed 's/\.json$//' | sort)
profile_labels=()
for p in "${profiles[@]}"; do profile_labels+=("$(jq -r .description "$settings/$p.json")"); done

me=$(gh api user --jq .login)
say "${bold}New AKTIN repository${reset}"
say "${dim}Creates github.com/<account>/<name> and clones it into $PWD/<name>.${reset}"

name=$(ask_required "Repository name" "Also the local folder, the project name and the package name")
dest="$PWD/$name"
state="$PWD/.$name.new-repo"

if [ -f "$state" ]; then
  # shellcheck source=/dev/null
  source <(grep -v '^done ' "$state")
  say "${bold}Resuming${reset} ${dim}with the answers from $state${reset}"
  mapfile -t stack_layers < <(layers "$stack")
else
  [ ! -e "$dest" ] || fail "$dest already exists"
  owner=$(ask "GitHub account" aktin "Organization or user the repository belongs to")
  if ! $local_only && gh repo view "$owner/$name" >/dev/null 2>&1; then fail "github.com/$owner/$name already exists"; fi
  stack=${stacks[$(choose "Stack" "${stacks[@]}")]}
  mapfile -t stack_layers < <(layers "$stack")
  run_hooks requirements.sh "$PWD"
  profile=${profiles[$(choose "Settings profile" "${profile_labels[@]}")]}
  description=$(ask_required "GitHub description" "One line, shown on the repository page and in the README")
  read -ra others <<<"$(ask "Code owners besides @$me" "" "Must approve pull requests into main. Separate by spaces, for example @alice @aktin/devs. Empty for none")"
  codeowners="@$me"
  for other in "${others[@]}"; do codeowners+=" @${other#@}"; done
  author=$(ask "Author" "$(git config user.name || true)" "Your name in the package metadata, for example pyproject.toml")

  say ""
  say "${bold}Summary${reset}"
  say "  Repository   github.com/$owner/$name (public)"
  say "  Local folder $dest"
  if $local_only; then say "  ${bold}Mode         --local, nothing is created on GitHub${reset}"; fi
  say "  Stack        $stack"
  say "  Profile      $profile"
  say "  Code owners  $codeowners"
  say "  Author       $author"
  say "  Description  $description"
  read -rp "  Create it? [y/N] › " confirm
  [[ "$confirm" =~ ^[yY]$ ]] || fail "Cancelled, nothing was created"
  declare -p owner name stack profile description codeowners author local_only >"$state"
fi

module=$(tr '[:upper:]' '[:lower:]' <<<"$name" | tr '.-' '__')
export TPL_PROJECT_NAME="$name" TPL_REPO_SLUG="$owner/$name" TPL_DESCRIPTION="$description" \
  TPL_OWNER="$me" TPL_CODEOWNERS="$codeowners" TPL_AUTHOR="$author" TPL_PROFILE="$profile" TPL_MODULE="$module"

run_step files "Copying the starter files"
run_step version "Setting the versions"
run_step setup "Setting up the stack"
run_step commit "First commit"
run_step github "Creating github.com/$owner/$name"
run_step branches "Creating the protected branches"
run_step settings "Applying the settings profile $profile"
rm "$state"

say ""
if $local_only; then
  say "${green}${bold}✔ Built $name locally${reset} in $dest"
else
  say "${green}${bold}✔ Created github.com/$owner/$name${reset} in $dest"
  say "  Next: the manual steps in section 4 of starter/README.md"
fi
