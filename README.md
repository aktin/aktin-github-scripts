## aktin-github-scripts

Reusable GitHub workflows and git hooks for the AKTIN repositories.

### Folder Structure:

- **.github/workflows/**: Reusable GitHub workflows.
- **hooks/**: Shared git hooks for [lefthook](https://lefthook.dev), plus an example configuration for the pre-commit framework.

### Workflows:

| Workflow            | What it does                                                                                                                                                                                                                                                 | Permissions of the calling job                                                |
|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------|
| `verify-common`     | Lints all Dockerfiles with hadolint, all `*.sh` files with shellcheck and all workflow files with actionlint                                                                                                                                                 | `contents: read`                                                              |
| `verify-java`       | Runs `verify-common` and `./mvnw -B verify`                                                                                                                                                                                                                  | `contents: read`                                                              |
| `verify-web`        | Runs `verify-common`, then the bun scripts `format:check`, `lint`, `typecheck`, `test` and `build`                                                                                                                                                           | `contents: read`                                                              |
| `verify-python`     | Runs `verify-common`, then ruff, mypy, pytest and `uv build`                                                                                                                                                                                                 | `contents: read`                                                              |
| `build-java`        | Builds the jar of a Maven project with the version from the tag and generates its SBOM                                                                                                                                                                       | `contents: read`                                                              |
| `build-web`         | Builds the web bundle of a bun project with the version from the tag, packs it as `.tgz` and generates its SBOM                                                                                                                                              | `contents: read`                                                              |
| `build-python`      | Builds wheel and sdist of a uv project with the version from the tag and generates their SBOM                                                                                                                                                                | `contents: read`                                                              |
| `publish-release`   | Writes release notes with git-cliff, attests the built files and publishes a GitHub Release with the files and their SBOMs attached. Runs after a `build-` workflow, which follows its `verify-` workflow                                                    | `contents: write`, `id-token: write`, `attestations: write`                   |
| `publish-image`     | Runs the build script of the calling repository and pushes the images it built to GHCR. Signs each image, generates its SBOM and attests build provenance and the SBOM                                                                                       | `contents: read`, `packages: write`, `id-token: write`, `attestations: write` |
| `scan-codeql`       | Runs CodeQL static analysis for the given languages and reports to the code scanning tab                                                                                                                                                                     | `actions: read`, `contents: read`, `security-events: write`                   |
| `scan-dependencies` | Blocks a pull request that adds a dependency with a known vulnerability of severity high or worse and comments the findings in the pull request                                                                                                              | `contents: read`, `pull-requests: write`                                      |
| `scan-scorecard`    | Runs the OpenSSF Scorecard analysis and publishes the result                                                                                                                                                                                                 | `contents: read`, `security-events: write`, `id-token: write`                 |
| `scan-security`     | Scans the repository with Trivy for secrets, misconfigurations and vulnerable dependencies, optionally also a list of published container images. Reports findings of severity HIGH and CRITICAL to the code scanning tab, the run does not fail on findings | `contents: read`, `security-events: write`                                    |

A project calls exactly one of `verify-java`, `verify-web` and `verify-python`, or `verify-common` alone. Inputs and requirements of each workflow are described in the comment at the top of its file.

#### Usage:

Reference a workflow file inside `.github/workflows/` as a job. `@main` follows this repository, a commit SHA pins a version. This example attaches a jar to a GitHub Release and packages it into an
image:

```yaml
# .github/workflows/release.yml
on:
  push:
    tags: [ 'v*' ]

permissions:
  contents: read

jobs:
  verify:
    uses: aktin/aktin-github-scripts/.github/workflows/verify-java.yml@main
  build:
    needs: verify
    uses: aktin/aktin-github-scripts/.github/workflows/build-java.yml@main
  image:
    needs: build
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write
    uses: aktin/aktin-github-scripts/.github/workflows/publish-image.yml@main
    with:
      build-command: ./build.sh
      images: '["ghcr.io/aktin/my-app"]'
      release-files-path: release-files
  release:
    needs: image
    permissions:
      contents: write
      id-token: write
      attestations: write
    uses: aktin/aktin-github-scripts/.github/workflows/publish-release.yml@main
```

### Git Hooks:

| Hook                      | What it does                                                                                                | Configuration                                                                                                                                                                                                               | Needs on PATH                                     |
|---------------------------|-------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------|
| `block_data_files.py`     | Rejects staged data files (`.csv`, `.xlsx`, `.sql`, `.dcm`, `.hl7`, ...) outside the allowed folders        | Allowed folders, comma separated, in the environment variable `DATA_FILE_ALLOWLIST`. Default is `tests/fixtures/`. Example: `env: { DATA_FILE_ALLOWLIST: "src/resources/database/" }` on the script entry in `lefthook.yml` | python3                                           |
| `check_large_files.py`    | Rejects staged files larger than 500 KB                                                                     | none                                                                                                                                                                                                                        | python3                                           |
| `check_commit_size.py`    | Rejects commits that change more than 200 lines in total (insertions plus deletions)                        | Limit with `--max-lines`                                                                                                                                                                                                    | python3                                           |
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
