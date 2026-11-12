## aktin-github-scripts
This repository contains a collection of custom GitHub Actions and Github Workflows to automate various tasks. These scripts can be used in your GitHub repository to streamline your development and deployment processes.

### Folder Structure:

- **workflows/**: Contains reusable GitHub workflow files.
- **hooks/**: Contains shared git hooks for [lefthook](https://lefthook.dev), plus an example configuration for the pre-commit framework.

### Workflows:

- **debian-build**: Builds a Debian package, runs integration tests, and uploads the `.deb` as a build artifact
- **debian-deploy**: Retrieves the `.deb` build artifact and adds it to a remote Debian repository using `reprepro`
- **maven-build-deploy**: Builds a Maven project, runs integration tests, and optionally deploys `.jar`/`.war`/`.ear` files to the AKTIN Maven repository
- **dependency-review**: Blocks a pull request that adds a dependency with a known vulnerability of severity high or worse
- **codeql**: Runs CodeQL static analysis for the given languages and reports to the code scanning tab
- **verify-base**: Lints all Dockerfiles with hadolint, all `*.sh` files with shellcheck and all workflow files with actionlint

#### Usage:

To use a reusable GitHub workflow from this repository, reference the workflow file inside `.github/workflows/`.

```yaml
# .github/workflows/my-workflow.yml
name: My Workflow
on:
  push:
    branches:
      - main

jobs:
  call-reusable-workflow:
    uses: aktin/aktin-github-scripts/.github/workflows/workflow1.yml@main
    with:
      input1: 'value1'
      input2: 'value2'
    secrets:
      my_secret: ${{ secrets.MY_SECRET }}
```

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

Copy the `hooks/` folder into your repository and use `hooks/pre-commit-config.example.yaml` as your `.pre-commit-config.yaml`. Adjust the `entry` paths if you rename the folder. Then install the hooks once with `pre-commit install`.

### License:

This repository is licensed under GNU Affero General Public License v3.0. See the LICENSE file for more details.
