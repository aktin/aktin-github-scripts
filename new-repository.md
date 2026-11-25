## New repository

The first stop when you set up a new AKTIN repository. Work through the six sections in order. Each section starts with the terms it uses.

### 1. Before you start

| Term                 | What it is                                                                                           |
|----------------------|------------------------------------------------------------------------------------------------------|
| Git hook             | A script that git runs at a fixed point, for example before a commit, and that can reject the commit |
| lefthook             | The hook manager that loads the shared AKTIN hooks into your repository                              |
| Conventional Commits | The commit message format `<type>(<scope>): <subject>`, checked by one of the hooks                  |
| Signed commit        | A commit that carries your GPG or SSH signature. The branch rules reject commits without one         |

The git hooks are mandatory in every AKTIN repository. Nothing on the server forces you to install them, so installing them once in every clone is your duty. One of them rejects a commit message that does not follow Conventional Commits.

Install these tools. All of them must be on your PATH, the environment variable that lists the folders in which your shell looks for commands:

| Tool                                                | Needed for                                                                              |
|-----------------------------------------------------|-----------------------------------------------------------------------------------------|
| [gh](https://cli.github.com)                        | Creating the repository and applying its settings                                       |
| [jq](https://jqlang.org)                            | Applying the settings                                                                   |
| [lefthook](https://lefthook.dev) 2.0.5 or newer     | Running the git hooks. The Python and the web starter install it themselves             |
| python3, gitleaks, actionlint, hadolint, shellcheck | The shared hooks, see [Git Hooks](README.md#git-hooks). A missing tool fails the commit |

Then do these two steps once per machine:

1. Log in to GitHub on the command line:
   ```bash
   gh auth login
   ```
2. Set up signed commits as described in the [GitHub documentation](https://docs.github.com/en/authentication/managing-commit-signature-verification).

### 2. Pick a starter

| Term                | What it is                                                                                         |
|---------------------|----------------------------------------------------------------------------------------------------|
| Template repository | A repository whose files GitHub copies into a new repository. Settings and rulesets are not copied |

| Starter                                                    | For                      | Stack                                                                                                                                                         |
|------------------------------------------------------------|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [java-starter](https://github.com/akomii/java-starter)     | Spring Boot applications | Maven (build tool), Spring Boot (application framework), Spotless (formatter), Checkstyle (linter), JUnit 5 (tests), JaCoCo (test coverage)                   |
| [python-starter](https://github.com/akomii/python-starter) | Python packages          | uv (package and environment manager), ruff (linter and formatter), mypy (type checker), pytest (tests)                                                        |
| [web-starter](https://github.com/akomii/web-starter)       | Vue web frontends        | bun (runtime and package manager), Vue 3 with TypeScript (UI framework), Vite (dev server and bundler), Vitest (tests), ESLint (linter), Prettier (formatter) |

Every starter is a template repository and brings the shared git hooks, the workflows and a README that explains its tools. If no starter fits, ask in the team before you create the repository.

### 3. Create the repository

| Term              | What it is                                                                                                                                                |
|-------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Reusable workflow | A GitHub Actions workflow that lives in this repository and that other repositories call as a job. The workflow files of a starter only hold the triggers |

1. Create the repository from the starter and clone it. Example for the Java starter:
   ```bash
   gh repo create aktin/my-repository --template akomii/java-starter --public --clone
   ```
   A private repository needs paid GitHub features, see "Private repository" in the README of the starter.
2. Open the README of the new repository and follow the setup steps in the box at the top. They fill in the placeholders, install the git hooks and push the first commit to `main`.
3. Stop before the last setup step, the repository settings. Section 4 covers them.

Everyone who clones the repository later installs the hooks once as well. The command is in the README of the repository under "Getting started".

The workflow files in `.github/workflows/` of the new repository call the reusable workflows of this repository.

### 4. Apply the settings

| Term             | What it is                                                                                            |
|------------------|-------------------------------------------------------------------------------------------------------|
| Ruleset          | A set of rules that GitHub enforces on branches or tags, for example "no push without a pull request" |
| Required check   | A workflow job that must pass before a pull request can be merged                                     |
| Settings profile | A JSON file in `repo-settings/` that holds the complete settings of a repository                      |
| Dependabot       | The GitHub service that reports vulnerable dependencies and opens pull requests that update them      |

1. Pick a settings profile:

   | Profile           | Use it when                          | Branches                                                                    |
   |-------------------|--------------------------------------|-----------------------------------------------------------------------------|
   | `no-release.json` | The repository publishes no releases | Feature branches go to `main`                                               |
   | `release.json`    | The repository publishes releases    | Feature branches go to `dev`, `dev` goes to `main`, a release is a tag `v*` |

2. Only for `release.json`: create the branch `dev` and point Dependabot at it, as described under "Branch `dev` for releases" in the README of your repository. Do this now, because the rulesets block direct pushes afterwards.
3. Clone this repository and run the script from its root with your repository and the settings profile from step 1. Replace `<profile>` with `no-release` or `release`:
   ```bash
   git clone https://github.com/aktin/aktin-github-scripts
   cd aktin-github-scripts
   repo-settings/apply.sh aktin/my-repository repo-settings/<profile>.json
   ```
   The script prints one `ok` line per part it applied. It needs admin rights on the repository, which you have on a repository you created.

What a settings profile contains is described under [Repository Settings](README.md#repository-settings).

### 5. Manual steps

The script does not cover these settings. Set them by hand in the repository on GitHub:

| Setting                | Where and what to do                                                                                                                                              | Why                                                                             |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------|
| Fork PR approval       | Settings → Actions → General → Approval for running fork pull request workflows from contributors. Select Require approval for all external contributors          | Keeps untrusted fork code from running workflows before a maintainer has looked |
| Labels                 | Issues → Labels. Delete `duplicate` and `invalid`, add `critical` (`B60205`, "Blocking release or core functionality") and `minor` (`FEF2C0`, "Low impact issue") | Same triage labels in every repository                                          |
| Description and topics | Start page of the repository, gear icon next to About                                                                                                             | Others find the repository and see what it is for                               |

### 6. Check

1. Create a feature branch, commit a small change and push it. lefthook prints the hooks it ran during the commit. If it prints nothing, the hooks are not installed, go back to section 3.
2. Open a pull request into `main`, or into `dev` if you applied `release.json`.
3. Wait for the required checks. `verify / verify` must turn green, with `release.json` also `review / review`.
4. Ask a team member for a review. The merge stays blocked until the checks are green and the pull request is approved. On `main` the approval must come from a code owner listed in `.github/CODEOWNERS`.

Once the pull request is merged, the repository is set up.
