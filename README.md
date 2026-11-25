## aktin-github-scripts

Reusable GitHub workflows, git hooks and repository settings profiles for the AKTIN repositories.

Setting up a new repository? Start with the [new repository guide](new-repository.md).

### Folder Structure:

- **.github/workflows/**: Reusable GitHub workflows.
- **hooks/**: Shared git hooks for [lefthook](https://lefthook.dev).
- **repo-settings/**: Repository settings profiles and a script that applies one to a repository.

### Workflows:

| Workflow              | What it does                                                                                                                                                                                                                                                 | Permissions of the calling job                                                |
|-----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| `verify-common`       | Lints all Dockerfiles with hadolint, all `*.sh` files with shellcheck and all workflow files with actionlint. Fails a pull request with more than `pr-max-lines` added plus deleted lines, 400 by default                                                    | `contents: read`                                                              |
| `verify-java`         | Runs `verify-common` and `./mvnw -B verify`. On push to the default branch it submits the Maven dependency tree to the dependency graph                                                                                                                      | `contents: write`                                                             |
| `verify-web`          | Runs `verify-common`, then the [bun](https://bun.sh) scripts `format:check`, `lint`, `typecheck`, `test` and `build`                                                                                                                                         | `contents: read`                                                              |
| `verify-python`       | Runs `verify-common`, then [ruff](https://docs.astral.sh/ruff/), mypy, pytest and `uv build`                                                                                                                                                                 | `contents: read`                                                              |
| `build-java`          | Builds the jar of a Maven project with the version from the tag, generates its SBOM and attests both                                                                                                                                                         | `contents: read`, `id-token: write`, `attestations: write`                    |
| `build-web`           | Builds the web bundle of a bun project with the version from the tag, packs it as `.tgz`, generates its SBOM and attests both                                                                                                                                | `contents: read`, `id-token: write`, `attestations: write`                    |
| `build-python`        | Builds wheel and sdist of a [uv](https://docs.astral.sh/uv/) project with the version from the tag, generates their SBOM and attests both                                                                                                                    | `contents: read`, `id-token: write`, `attestations: write`                    |
| `build-publish-image` | Runs the build script of the calling repository and pushes the images it built to GHCR. Generates the SBOM of each image and attests build provenance and the SBOM                                                                                           | `contents: read`, `packages: write`, `id-token: write`, `attestations: write` |
| `publish-release`     | Writes release notes with git-cliff and publishes a GitHub Release with the files of all `build-` jobs of the run attached. Runs after a `build-` workflow, which follows its `verify-` workflow                                                             | `contents: write`                                                             |
| `scan-codeql`         | Runs [CodeQL](https://codeql.github.com) static analysis for the given languages and reports to the code scanning tab                                                                                                                                        | `actions: read`, `contents: read`, `security-events: write`                   |
| `scan-dependencies`   | Blocks a pull request that adds a dependency with a known vulnerability of severity high or worse and comments the findings in the pull request                                                                                                              | `contents: read`, `pull-requests: write`                                      |
| `scan-scorecard`      | Runs the [OpenSSF Scorecard](https://scorecard.dev) analysis and publishes the result                                                                                                                                                                        | `contents: read`, `security-events: write`, `id-token: write`                 |
| `scan-image`          | Scans published container images with [Trivy](https://trivy.dev). Reports findings of severity HIGH and CRITICAL to the code scanning tab, the run does not fail on findings                                                                                                      | `contents: read`, `security-events: write`                                    |

A project calls the verify workflow of each build tool it uses, or `verify-common` alone. A release with several build tools runs their `build-` workflows side by side and one `publish-release` after them. Every `build-` workflow takes the input `attest`. If it is set to `false`, the SBOM and the attestations are skipped. Inputs and requirements of each workflow are described in the comment at the top of its file. A pull request with `[skip-size]` in its title is not checked against `pr-max-lines`.

> [!NOTE]
> An SBOM (Software Bill of Materials) is an inventory of the components and dependencies that make up a piece of software.

#### Usage:

Reference a workflow file inside `.github/workflows/` as a job. `@main` follows this repository, a commit SHA pins a version. This example attaches a jar to a GitHub Release and packages it into an
image:

```yaml
# .github/workflows/release.yml
on:
  push:
    tags:
      - "v*"

permissions:
  contents: read

jobs:
  verify:
    permissions:
      contents: write
    uses: aktin/aktin-github-scripts/.github/workflows/verify-java.yml@main
  build:
    needs: verify
    permissions:
      contents: read
      id-token: write
      attestations: write
    uses: aktin/aktin-github-scripts/.github/workflows/build-java.yml@main
  images:
    needs: build
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write
    uses: aktin/aktin-github-scripts/.github/workflows/build-publish-image.yml@main
    with:
      build-command: ./build.sh
      images: '["ghcr.io/aktin/my-app"]'
      release-files-path: release-files
  publish:
    needs: images
    permissions:
      contents: write
    uses: aktin/aktin-github-scripts/.github/workflows/publish-release.yml@main
```

### Security Scans:

Workflows run the scans, the repository settings switch on the scans that GitHub runs itself. CodeQL default setup stays off, so CodeQL runs only through `scan-codeql`.

| Scan              | Runs as                         | Results                                     |
|-------------------|---------------------------------|---------------------------------------------|
| CodeQL            | workflow `scan-codeql`          | code scanning tab                           |
| Trivy             | workflow `scan-image`           | code scanning tab, high and critical only   |
| OpenSSF Scorecard | workflow `scan-scorecard`       | code scanning tab and the Scorecard API     |
| Dependency review | workflow `scan-dependencies`    | check and comment in the pull request       |
| Dependabot        | setting `dependabot`            | Dependabot tab and pull requests with fixes |
| Secret scanning   | setting `security_and_analysis` | secret scanning tab, rejected pushes        |

### Git Hooks:

| Hook                      | What it does                                                                                                | Configuration                                                                                                                                                                                                               | Needs on PATH                                     |
|---------------------------|-------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------|
| `block_data_files.py`     | Rejects staged data files (`.csv`, `.xlsx`, `.sql`, `.dcm`, `.hl7`, ...) outside the allowed folders        | Allowed folders, comma separated, with `--allow`. Default is `tests/fixtures/`. Keep `{staged_files}` when you override `args`, example: `args: "--allow=src/resources/database/ {staged_files}"`                           | python3                                           |
| `check_large_files.py`    | Rejects staged files larger than 500 KB                                                                     | Limit in KB with `--max-kb`. Keep `{staged_files}` when you override `args`, example: `args: "--max-kb=2048 {staged_files}"`                                                                                                | python3                                           |
| `check_commit_size.py`    | Rejects commits that change more than 200 lines in total (insertions plus deletions)                        | Limit with `--max-lines`. `[skip-size]` in the commit header skips the check                                                                                                                                                | python3                                           |
| `check_commit_message.py` | Validates the commit message against the EU System Conventional Commit rules (`<type>(<scope>): <subject>`) | none                                                                                                                                                                                                                        | python3                                           |
| gitleaks                  | Scans the staged changes for secrets                                                                        | none                                                                                                                                                                                                                        | [gitleaks](https://github.com/gitleaks/gitleaks)  |
| actionlint                | Lints staged workflow files under `.github/workflows/`                                                      | none                                                                                                                                                                                                                        | [actionlint](https://github.com/rhysd/actionlint) |
| hadolint                  | Lints staged Dockerfiles, fails on findings of level error                                                  | none                                                                                                                                                                                                                        | [hadolint](https://github.com/hadolint/hadolint)  |
| shellcheck                | Lints staged `*.sh` files, fails on findings of level warning or worse                                      | none                                                                                                                                                                                                                        | [shellcheck](https://www.shellcheck.net)          |

A missing tool fails the commit. A hook with a file filter only runs when a matching file is staged.

#### Usage with lefthook:

Add the remote to the `lefthook.yml` of your project. lefthook clones this repository into `.git/info/lefthook-remotes/`, merges `hooks/lefthook.yml` into your configuration and runs the scripts from
the clone. Requires lefthook 2.0.5 or newer.

```yaml
# lefthook.yml
remotes:
  - git_url: https://github.com/aktin/aktin-github-scripts
    ref: main
    refetch_frequency: 24h
    configs:
      - hooks/lefthook.yml
      - hooks/lefthook-java.yml # optional language profile
```

The language profiles add lint, format and pre-push hooks for one build tool. Pick the one that fits, or none:

| Profile                     | pre-commit                                                      | pre-push                                             | Expects in the project                                                            |
|-----------------------------|-----------------------------------------------------------------|------------------------------------------------------|-----------------------------------------------------------------------------------|
| `hooks/lefthook-java.yml`   | Spotless formats and Checkstyle lints the staged `*.java` files | `./mvnw -B verify`                                   | Maven wrapper, Spotless and Checkstyle in the `pom.xml`                           |
| `hooks/lefthook-web.yml`    | ESLint fixes and Prettier formats the staged files              | `bun run typecheck`, `bun run test`, `bun run build` | bun, ESLint and Prettier as dev dependencies, the three scripts in `package.json` |
| `hooks/lefthook-python.yml` | `ruff format` and `ruff check --fix` on the staged `*.py` files | `uv run mypy`, `uv run pytest`, `uv build`           | uv, ruff, mypy and pytest configured in `pyproject.toml`                          |

The profiles only call the tools. The rules and settings of each tool stay in your project.

To use another source or a fixed version, change `git_url` and `ref`. `ref` must not contain a slash, so use a tag or a branch name without a slash. To change a hook, override its entry in `lefthook-local.yml`. Example: `args: "--max-lines=300"` for `check_commit_size.py`. The shared config sets `source_dir: hooks`. lefthook then also looks for the scripts of your own project in `hooks/`, not in `.lefthook/`.

### Repository Settings:

A profile holds the complete settings of a repository: merge options, who may open pull requests, Actions permissions, code scanning default setup, Dependabot, vulnerability reporting, immutable releases and the rulesets for branches and tags. `apply.sh` applies one profile to a repository.

#### Profiles:

| Profile           | For                                                                                     | Protected refs           | Required checks                      |
|-------------------|-----------------------------------------------------------------------------------------|--------------------------|--------------------------------------|
| `template.json`   | Template repositories                                                                   | `main`                   | none                                 |
| `no-release.json` | Repositories without a release process, feature branches go to `main`                   | `main`                   | `verify / verify`                    |
| `release.json`    | Repositories with a release process, feature branches go to `dev`, `dev` goes to `main` | `main`, `dev`, tags `v*` | `verify / verify`, `review / review` |

The required checks are the jobs of the `verify-` workflows and of `scan-dependencies`.

#### Usage:

Run the script with the repository and a profile. It needs `jq` and `gh`, logged in with admin rights on the repository. A repository created from a template does not inherit the settings of the template, so apply a profile to every new repository.

```bash
repo-settings/apply.sh aktin/my-repository repo-settings/release.json
```

The script replaces a ruleset that has the same name as one in the profile and leaves other rulesets untouched. A setting a profile does not contain stays as it is in the repository.

#### Settings:

##### Repository

| Setting                                                          | What it does                                                                             | `template`   | `no-release`      | `release`         |
|------------------------------------------------------------------|------------------------------------------------------------------------------------------|--------------|-------------------|-------------------|
| `is_template`                                                    | Marks the repository as a template for new repositories                                  | yes          | no                | no                |
| `has_issues`                                                     | Issues tab                                                                               | on           | on                | on                |
| `has_projects`                                                   | Projects tab                                                                             | off          | on                | on                |
| `has_wiki`                                                       | Wiki tab                                                                                 | off          | off               | off               |
| `has_discussions`                                                | Discussions tab                                                                          | off          | off               | off               |
| `has_pull_requests`                                              | Pull requests tab                                                                        | off          | not set           | not set           |
| `pull_request_creation_policy`                                   | Who may open pull requests                                                               | not set      | collaborators     | collaborators     |
| `allow_squash_merge`, `allow_merge_commit`, `allow_rebase_merge` | Merge methods the repository offers. The rulesets narrow them for the protected branches | all on       | all on            | all on            |
| `allow_auto_merge`                                               | Merges a pull request on its own once all requirements are met                           | off          | off               | off               |
| `allow_update_branch`                                            | Offers to update a pull request branch with the latest changes of its base branch        | on           | on                | on                |
| `delete_branch_on_merge`                                         | Deletes the head branch after its pull request is merged                                 | on           | on                | on                |
| `*_merge_commit_title`, `*_merge_commit_message`                 | Message of a squash or merge commit                                                      | PR title, no body | PR title, no body | PR title, no body |
| `web_commit_signoff_required`                                    | Commits made in the web interface need a sign off                                        | on           | on                | on                |
| `secret_scanning`                                                | Scans the repository for secrets                                                         | on           | on                | on                |
| `secret_scanning_push_protection`                                | Rejects pushes that contain secrets                                                      | on           | on                | on                |
| `secret_scanning_non_provider_patterns`                          | Also scans for generic secrets such as private keys                                      | off          | off               | off               |
| `secret_scanning_validity_checks`                                | Checks with the provider whether a found secret is still valid                           | off          | off               | off               |

##### Actions and Security

| Setting                            | What it does                                                                     | `template` | `no-release` | `release` |
|------------------------------------|----------------------------------------------------------------------------------|------------|--------------|-----------|
| `enabled`                          | GitHub Actions                                                                   | off        | on           | on        |
| `allowed_actions`                  | Actions that workflows may use                                                   | not set    | all          | all       |
| `sha_pinning_required`             | Workflows must reference actions by full commit SHA                              | not set    | on           | on        |
| `default_workflow_permissions`     | Default permissions of `GITHUB_TOKEN`                                            | read       | read         | read      |
| `can_approve_pull_request_reviews` | Workflows may approve pull requests                                              | no         | no           | no        |
| `fork_pr_approval`                 | Workflow runs of fork pull requests that need approval by a maintainer           | all external contributors | all external contributors | all external contributors |
| `artifact_retention`               | Days that artifacts and logs of workflow runs are kept                           | 30         | 30           | 30        |
| `code_scanning_default_setup`      | CodeQL default setup of GitHub. Code scanning runs only through workflows        | off        | off          | off       |
| `dependabot`                       | Dependabot alerts and security updates                                           | off        | on           | on        |
| `private_vulnerability_reporting`  | Others may report a vulnerability privately to the maintainers                   | off        | off          | off       |
| `immutable_releases`               | Assets and tag of a published release can no longer be changed                   | off        | off          | on        |

##### Rulesets

| Rule                                         | `template`: `default` | `no-release`: `default` | `release`: `default`                     | `release`: `dev`        | `release`: `release-tags`               |
|----------------------------------------------|-----------------------|-------------------------|------------------------------------------|-------------------------|-----------------------------------------|
| Applies to                                   | `main`                | `main`                  | `main`                                   | `dev`                   | tags `v*`                               |
| May bypass                                   | nobody                | organization admins     | organization admins                      | organization admins     | organization admins, repository role 2  |
| Blocks deletion                              | yes                   | yes                     | yes                                      | yes                     | yes                                     |
| Blocks force pushes                          | yes                   | yes                     | yes                                      | yes                     |                                         |
| Requires signed commits                      | yes                   | yes                     | yes                                      | yes                     |                                         |
| Requires a pull request                      | no                    | yes                     | yes                                      | yes                     |                                         |
| Allowed merge method                         |                       | squash                  | merge commit                             | squash                  |                                         |
| Required approvals                           |                       | 1                       | 1                                        | 1                       |                                         |
| Requires review by a code owner              |                       | yes                     | yes                                      | no                      |                                         |
| Dismisses approvals on new pushes            |                       | yes                     | yes                                      | no                      |                                         |
| Last push must be approved by someone else   |                       | yes                     | yes                                      | no                      |                                         |
| Extra approval for unattributed changes      |                       | yes                     | yes                                      | yes                     |                                         |
| All review threads must be resolved          |                       | yes                     | yes                                      | yes                     |                                         |
| Required status checks                       |                       | `verify / verify`       | `verify / verify`, `review / review`     | `verify / verify`, `review / review` |                            |
| Code scanning                                |                       |                         | CodeQL, fails on errors and on security alerts high or higher |   |                                         |
| Blocks creation and update of tags           |                       |                         |                                          |                         | yes                                     |

An empty cell means the rule is not part of the ruleset. The status checks must come from GitHub Actions.

### License:

This repository is licensed under GNU Affero General Public License v3.0. See the LICENSE file for more details.
