## New repository

The first stop when you set up a new AKTIN repository. Work through the numbered sections in order. Each section starts with the terms it uses.

### 1. Before you start

| Term                 | What it is                                                                                           |
|----------------------|------------------------------------------------------------------------------------------------------|
| Git hook             | A script that git runs at a fixed point, for example before a commit, and that can reject the commit |
| lefthook             | The hook manager that loads the shared AKTIN hooks into your repository                              |
| Conventional Commits | The commit message format `<type>(<scope>): <subject>`, checked by one of the hooks                  |
| Signed commit        | A commit that carries your GPG or SSH signature. The branch rules reject commits without one         |

The git hooks are mandatory in every AKTIN repository. `new-repo.sh` installs them in the clone it creates. Everyone who clones the repository later installs them once, the command is in the README of the repository under "Getting started".

Install these tools. All of them must be on your PATH, the environment variable that lists the folders in which your shell looks for commands:

| Tool                                                | Needed for                                                                              |
|-----------------------------------------------------|-----------------------------------------------------------------------------------------|
| [gh](https://cli.github.com)                        | Creating the repository and applying its settings                                       |
| [jq](https://jqlang.org)                            | Applying the settings                                                                   |
| The build tool of your stack                        | Locking the dependencies and installing the hooks, for Python [uv](https://docs.astral.sh/uv/) |
| python3, gitleaks, actionlint, hadolint, shellcheck | The shared hooks, see [Git Hooks](../README.md#git-hooks). A missing tool fails the commit |

Then do these two steps once per machine:

1. Log in to GitHub on the command line:
   ```bash
   gh auth login
   ```
2. Set up signed commits as described in the [GitHub documentation](https://docs.github.com/en/authentication/managing-commit-signature-verification).

### 2. Pick a stack and a profile

| Term             | What it is                                                                                     |
|------------------|------------------------------------------------------------------------------------------------|
| Stack            | A folder in `starter/` with the files of one kind of project                                   |
| Settings profile | A JSON file in `../repo-settings/` that holds the complete settings and rulesets of a repository |
| Ruleset          | A set of rules that GitHub enforces on branches or tags, for example "no push without a pull request" |
| Required check   | A workflow job that must pass before a pull request can be merged                              |

| Stack    | For             | Tools                                                                                     |
|----------|-----------------|-------------------------------------------------------------------------------------------|
| `python` | Python packages | uv (package and environment manager), ruff (linter and formatter), mypy (type checker), pytest (tests) |

Java and web are still the template repositories [java-starter](https://github.com/akomii/java-starter) and [web-starter](https://github.com/akomii/web-starter). Create them with `gh repo create --template` and apply the profile with `repo-settings/apply.sh` as described in [Repository Settings](../README.md#repository-settings).

| Profile      | Use it when                          | Branches                                                                    |
|--------------|--------------------------------------|-----------------------------------------------------------------------------|
| `no-release` | Without release cycle: prototypes, simple or internal tools, where a failure has little impact | Feature branches go to `main`                                               |
| `release`    | With release cycle: apps that are shipped or run in production, where a failure has real impact | Feature branches go to `dev`, `dev` goes to `main`, a release is a tag `v*` |

### 3. Create the repository

Clone this repository once. Then change to the folder in which the new repository should land and run the script from there by its path. It creates the repository in a subfolder named after it:

```bash
git clone https://github.com/aktin/aktin-github-scripts ~/aktin-github-scripts
cd ~/projects
~/aktin-github-scripts/new-repo.sh
```

The script asks for:

| Question         | Meaning                                                                                                              |
|------------------|----------------------------------------------------------------------------------------------------------------------|
| GitHub account   | Organization or user the repository is created under, the `<account>` in `github.com/<account>/<name>`. `aktin` by default |
| Repository name  | The `<name>` in the URL and the local folder. Also the project name and, for Python, the package name                |
| Stack            | See section 2                                                                                                        |
| Settings profile | With or without release cycle, see section 2                                                                         |
| Visibility       | A private repository needs paid GitHub features, see "Private repository" in its README                             |
| GitHub description | Mandatory. One line, shown on the repository page and as the subtitle of the README                                |
| Code owners      | Who must approve every pull request into `main`, written to `.github/CODEOWNERS`. You are always one. Add further users or teams with `@`, separated by spaces, for example `@alice @aktin/devs` |
| Author           | Your name in the package metadata, for example `authors` in `pyproject.toml`. Your git `user.name` by default        |

The script then makes the first commit, pushes `main`, creates `dev` if the profile protects it and applies the profile. It prints one `ok` line per part of the profile. What a profile contains is described under [Repository Settings](../README.md#repository-settings).

### 4. Manual steps

The script does not cover these settings. Set them by hand in the repository on GitHub:

| Setting                | Where and what to do                                                                                                                                              | Why                                                                             |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| Fork PR approval       | Settings → Actions → General → Approval for running fork pull request workflows from contributors. Select Require approval for all external contributors          | Keeps untrusted fork code from running workflows before a maintainer has looked |
| Labels                 | Issues → Labels. Delete `duplicate` and `invalid`, add `critical` (`B60205`, "Blocking release or core functionality") and `minor` (`FEF2C0`, "Low impact issue") | Same triage labels in every repository                                          |
| Description and topics | Start page of the repository, gear icon next to About                                                                                                             | Others find the repository and see what it is for                               |

### 5. Check

1. Create a feature branch, commit a small change and push it. lefthook prints the hooks it ran during the commit. If it prints nothing, the hooks are not installed, go back to section 3.
2. Open a pull request into `main`, or into `dev` if you applied `release.json`.
3. Wait for the required checks. `verify / verify` must turn green, with `release.json` also `review / review`.
4. Ask a team member for a review. The merge stays blocked until the checks are green and the pull request is approved. On `main` the approval must come from a code owner listed in `.github/CODEOWNERS`.

Once the pull request is merged, the repository is set up.

### Add a stack

A stack folder only holds what differs from `common/` and its parent stacks. The stack `python-flask` gets the files of `common`, `python` and `python-flask`, in this order, a later file replaces an earlier one. Inside a stack folder:

| Path                  | Meaning                                                                                       |
|-----------------------|-----------------------------------------------------------------------------------------------|
| `profile/<profile>/`  | Files only for that profile, for example `release.yml`. Not copied for other profiles        |
| `setup.sh`            | Runs in the new repository after the copy, for example to lock dependencies and install hooks |
| `{{NAME}}`            | Placeholder in file contents and paths, see `new-repo.sh` for the names                        |
| `profile:<profile>:start` and `profile:<profile>:end` | Lines in any file that enclose text only for that profile        |
