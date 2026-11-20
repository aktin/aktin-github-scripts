## aktin-github-scripts

Reusable GitHub workflows and git hooks for the AKTIN repositories.

### Folder Structure:

- **.github/workflows/**: Reusable GitHub workflows.
- **hooks/**: Shared git hooks for [lefthook](https://lefthook.dev), plus an example configuration for the pre-commit framework.

### Workflows:

| Workflow              | What it does                                                                                                                                                                                                                                                 | Permissions of the calling job                                                |
|-----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| `verify-common`       | Lints all Dockerfiles with hadolint, all `*.sh` files with shellcheck and all workflow files with actionlint. Fails a pull request with more than `pr-max-lines` added plus deleted lines, 400 by default                                                    | `contents: read`                                                              |
| `verify-java`         | Runs `verify-common` and `./mvnw -B verify`                                                                                                                                                                                                                  | `contents: read`                                                              |
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
| `scan-image`          | Scans published container images with Trivy. Reports findings of severity HIGH and CRITICAL to the code scanning tab, the run does not fail on findings                                                                                                      | `contents: read`, `security-events: write`                                    |

A project calls the verify workflow of each build tool it uses, or `verify-common` alone. A release with several build tools runs their `build-` workflows side by side and one `publish-release` after them. Every `build-` workflow takes the input `attest`. Set to `false` it skips the SBOM and the attestations. Inputs and requirements of each workflow are described in the comment at the top of its file. A pull request with `[skip-size]` in its title is not checked against `pr-max-lines`.

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

### License:

This repository is licensed under GNU Affero General Public License v3.0. See the LICENSE file for more details.
