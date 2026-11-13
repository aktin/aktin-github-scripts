## aktin-github-scripts
Reusable GitHub workflows and git hooks for the AKTIN repositories.

### Folder Structure:

- **.github/workflows/**: Reusable GitHub workflows.
- **hooks/**: Shared git hooks for [lefthook](https://lefthook.dev), plus an example configuration for the pre-commit framework.

### Workflows:

The prefix names the responsibility: `verify-` checks, `build-` produces files, `publish-` releases them, `scan-` analyses.

| Workflow | Call it on | What it does | Permissions of the calling job |
|---|---|---|---|
| `verify-common` | pull request, push to the default branch | Lints all Dockerfiles with hadolint, all `*.sh` files with shellcheck and all workflow files with actionlint | `contents: read` |
| `verify-java` | pull request, push to the default branch | Runs `verify-common` and `./mvnw -B verify` | `contents: read` |
| `verify-web` | pull request, push to the default branch | Runs `verify-common`, then the bun scripts `format:check`, `lint`, `typecheck`, `test` and `build` | `contents: read` |
| `verify-python` | pull request, push to the default branch | Runs `verify-common`, then ruff, mypy, pytest and `uv build` | `contents: read` |
| `build-java` | tag `v*` | Builds the jar of a Maven project with the version from the tag and generates its SBOM | `contents: read` |
| `build-web` | tag `v*` | Builds the web bundle of a bun project with the version from the tag, packs it as `.tgz` and generates its SBOM | `contents: read` |
| `build-python` | tag `v*` | Builds wheel and sdist of a uv project with the version from the tag and generates their SBOM | `contents: read` |
| `publish-release` | tag `v*` | Writes release notes with git-cliff, attests the built files and publishes a GitHub Release with the files and their SBOMs attached | `contents: write`, `id-token: write`, `attestations: write` |
| `publish-image` | tag `v*`, schedule | Runs the build script of the calling repository and pushes the images it built to GHCR. Signs each image, generates its SBOM and attests build provenance and the SBOM | `contents: read`, `packages: write`, `id-token: write`, `attestations: write` |
| `scan-codeql` | pull request, push to the default branch | Runs CodeQL static analysis for the given languages and reports to the code scanning tab | `actions: read`, `contents: read`, `security-events: write` |
| `scan-dependencies` | pull request | Blocks a pull request that adds a dependency with a known vulnerability of severity high or worse and comments the findings in the pull request | `contents: read`, `pull-requests: write` |
| `scan-scorecard` | push to the default branch, schedule | Runs the OpenSSF Scorecard analysis and publishes the result | `contents: read`, `security-events: write`, `id-token: write` |
| `scan-security` | schedule | Scans the repository with Trivy for secrets, misconfigurations and vulnerable dependencies, optionally also a list of published container images. Reports findings of severity HIGH and CRITICAL to the code scanning tab, the run does not fail on findings | `contents: read`, `security-events: write` |

A project calls exactly one of `verify-java`, `verify-web` and `verify-python`, or `verify-common` alone. Inputs and requirements of each workflow are described in the comment at the top of its file.

#### How the release workflows pass files on:

`build-` and `publish-` workflows run as separate jobs of one run and hand files over as artifacts with fixed names. The artifacts are kept for one day.

| Artifact | Uploaded by | Used by |
|---|---|---|
| `release-files` | `build-java`, `build-web`, `build-python`, or `publish-image` with the input `upload-release-files` | `publish-release` attests the files and attaches them to the release. `publish-image` with the input `release-files-path` puts them where the build script packages them into an image |
| `release-sbom` | `build-java`, `build-web`, `build-python` | `publish-release` attests it as the SBOM of `release-files` and attaches it. Without it the release is published without an SBOM |
| `release-extras-<image>` | `publish-image`, one per image with its SBOM | `publish-release` attaches every artifact whose name starts with `release-extras`, without attestation |

#### Usage:

Reference a workflow file inside `.github/workflows/` as a job. `@main` follows this repository, a commit SHA pins a version. This release attaches a jar to a GitHub Release and packages it into an image:

```yaml
# .github/workflows/release.yml
on:
  push:
    tags: ['v*']

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

Leave out the job `image` to release only the jar, then `release` needs `build`.

### Git Hooks:

- **block_data_files.py**: Rejects staged data files (`.csv`, `.xlsx`, `.sql`, `.dcm`, `.hl7`, ...) outside `tests/fixtures/` to keep patient data out of the repository. Set other allowed path prefixes, comma separated, with the environment variable `DATA_FILE_ALLOWLIST`, for example `env: { DATA_FILE_ALLOWLIST: "src/resources/database/" }` on the script entry in `lefthook.yml`
- **check_large_files.py**: Rejects staged files larger than 500 KB
- **check_commit_size.py**: Rejects commits that change more than 200 lines in total (insertions plus deletions). Configure the limit with `--max-lines`
- **check_commit_message.py**: Validates the commit message against the EU System Conventional Commit rules (`<type>(<scope>): <subject>`)
- **gitleaks**: Scans the staged changes for secrets. Needs [gitleaks](https://github.com/gitleaks/gitleaks) on PATH
- **actionlint**: Lints staged workflow files under `.github/workflows/`. Needs [actionlint](https://github.com/rhysd/actionlint) on PATH
- **hadolint**: Lints staged Dockerfiles, fails on findings of level error. Needs [hadolint](https://github.com/hadolint/hadolint) on PATH
- **shellcheck**: Lints staged `*.sh` files, fails on findings of level warning or worse. Needs [shellcheck](https://www.shellcheck.net) on PATH

The `.py` hooks are plain Python scripts and need `python3` on PATH. A missing tool fails the commit. A hook with a file filter only runs when a matching file is staged, so a project without Dockerfiles never calls hadolint. Nothing is enforced in this repository, the hooks are an offer for other repositories.

#### Usage with lefthook:

Add the remote to the `lefthook.yml` of your project. lefthook clones this repository into `.git/info/lefthook-remotes/`, merges `hooks/lefthook.yml` into your configuration and runs the scripts from the clone. Requires lefthook 2.0.5 or newer.

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

| Profile | pre-commit | pre-push | Expects in the project |
|---|---|---|---|
| `hooks/lefthook-java.yml` | Spotless formats and Checkstyle lints the staged `*.java` files | `./mvnw -B verify` | Maven wrapper, Spotless and Checkstyle in the `pom.xml` |
| `hooks/lefthook-web.yml` | ESLint fixes and Prettier formats the staged files | `bun run typecheck`, `bun run test`, `bun run build` | bun, ESLint and Prettier as dev dependencies, the three scripts in `package.json` |
| `hooks/lefthook-python.yml` | `ruff format` and `ruff check --fix` on the staged `*.py` files | `uv run mypy`, `uv run pytest`, `uv build` | uv, ruff, mypy and pytest configured in `pyproject.toml` |

The profiles only hold the hook calls. Rules and settings of the tools stay in the project.

Change `git_url` and `ref` to use another source or pin a version. `ref` must not contain a slash, lefthook uses it as part of a directory name, so use tags or plain branch names. To adjust a hook, override its script entry in `lefthook-local.yml`, for example `args: "--max-lines=300"` for `check_commit_size.py`. The remote config sets `source_dir: hooks`, so projects that keep their own lefthook scripts in `.lefthook/` need to account for that.

#### Usage with pre-commit:

Copy the `hooks/` folder into your repository and use `hooks/pre-commit-config.example.yaml` as your `.pre-commit-config.yaml`. The example holds the four `.py` hooks. Adjust the `entry` paths if you rename the folder. Then install the hooks once with `pre-commit install`.

### License:

This repository is licensed under GNU Affero General Public License v3.0. See the LICENSE file for more details.
