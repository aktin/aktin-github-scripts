# {{PROJECT_NAME}}

<!-- template:start -->

> This repository was created from the `python-starter` template. Do this one-time setup before anything else:
>
> 1. Install the dependencies and fill in the placeholders. The script reads your `git remote` to guess the slug and asks for the rest:
>    ```sh
>    uv sync
>    uv run python scripts/init.py
>    ```
> 2. Install the git hooks:
>    ```sh
>    uv run lefthook install
>    ```
> 3. Sync the renamed package, review the diff, then commit and push it, for example:
>    ```sh
>    uv sync
>    git add -A
>    git commit -m "chore: fill in the template placeholders"
>    git push
>    ```
> 4. Do the GitHub steps under [Repository settings](#repository-settings).
>
> `init.py` rewrites the placeholders (`{{PROJECT_NAME}}`, `{{REPO_SLUG}}`, `{{DESCRIPTION}}`, `{{AUTHOR}}`, `{{OWNER}}`) across the repo, renames the `python_starter` package, strips this banner and deletes itself.

<!-- template:end -->

[![Verify](https://github.com/{{REPO_SLUG}}/actions/workflows/verify.yml/badge.svg)](https://github.com/{{REPO_SLUG}}/actions/workflows/verify.yml)
[![CodeQL](https://github.com/{{REPO_SLUG}}/actions/workflows/scan-codeql.yml/badge.svg)](https://github.com/{{REPO_SLUG}}/actions/workflows/scan-codeql.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/{{REPO_SLUG}}/badge)](https://securityscorecards.dev/viewer/?uri=github.com/{{REPO_SLUG}})
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
[![Release](https://img.shields.io/github/v/release/{{REPO_SLUG}})](https://github.com/{{REPO_SLUG}}/releases)

# {{DESCRIPTION}}

## Stack

uv-managed Python package (src layout), ruff for linting and formatting, mypy strict, pytest with coverage gate, lefthook with shared hooks from aktin-github-scripts, tag-driven releases via git-cliff, and a hardened GitHub Actions pipeline (CI, CodeQL, Scorecard, dependency review, SBOM, build attestations).

## Getting started

Prerequisites: [uv](https://docs.astral.sh/uv/) on PATH (it installs the interpreter pinned in `.python-version`). The shared git hooks need `python3`, `gitleaks`, `actionlint`, `hadolint` and `shellcheck` on PATH. A missing tool fails the commit. actionlint, hadolint and shellcheck are only called when a workflow file, Dockerfile or shell script is staged.

```sh
uv sync                  # deps + venv
uv run pytest            # unit tests with coverage
uv run mypy              # type check
uv run ruff check .      # lint
uv run ruff format .     # format
uv build                 # sdist + wheel
uv run lefthook install  # git hooks (one-time)
```

The coverage report lands in `htmlcov/index.html`.

Commits must follow [Conventional Commits](https://www.conventionalcommits.org), enforced by the commit-msg hook:

```
<type>(<optional scope>): <subject>
```

Allowed types are `feat fix docs style refactor perf test chore`, the subject starts lowercase and has no trailing period, every line of the message stays at most 100 characters.

To cut a release, check out the commit on `main` that you want to release, tag it `vX.Y.Z` and push the tag. Example for version 1.2.3:

```sh
git tag v1.2.3
git push origin v1.2.3
```

The tag starts `release.yml`, see [Workflows](.github/workflows/README.md#workflows).

## Repository settings

GitHub copies only the files of a template, not its settings or rulesets. Apply them once after `scripts/init.py`, as described from section 4 on in the [new repository guide](https://github.com/aktin/aktin-github-scripts/blob/main/new-repository.md) of aktin-github-scripts.

The code owners in `.github/CODEOWNERS` review every pull request into `main`. The init script suggests `akomii`. Enter whoever is responsible for the reviews in this repository.

### Branch `dev` for releases

A repository that publishes releases uses the settings profile `release.json`. Features collect on `dev`, `dev` goes to `main` and `main` mirrors the released state. Do these steps before you apply the profile, because its rulesets block direct pushes afterwards. A repository without releases uses `no-release.json` and skips this section.

1. Create `dev` from `main` and push it:
   ```sh
   git switch -c dev main
   git push -u origin dev
   ```
2. In `.github/dependabot.yml` add `target-branch: dev` to both entries. Example for the first entry:
   ```yaml
   - package-ecosystem: uv
     directory: /
     target-branch: dev
     schedule:
       interval: weekly
   ```

### Private repository

A private repository needs two things that cost extra:

| Needs | For | Without it |
| --- | --- | --- |
| GitHub Code Security | CodeQL and the dependency review | `review / review` fails and CodeQL delivers no result, so the ruleset `default` blocks every pull request |
| GitHub Enterprise Cloud | The attestations in `release.yml` | The job `build` fails and no release is published |

To release without attestations, add the input `attest: false` to the job `build` in `.github/workflows/release.yml`. The build then skips the SBOM and the attestations, and the release holds only the wheel and the sdist:

```yaml
  build:
    needs: verify
    permissions:
      contents: read
      id-token: write
      attestations: write
    uses: aktin/aktin-github-scripts/.github/workflows/build-python.yml@main
    with:
      attest: false
```

## How the infra works

| Component | What it does |
| --- | --- |
| uv | Package and environment manager, single lockfile |
| ruff | Owns linting and formatting |
| mypy strict | Type checks `src` and `tests` |
| pytest + coverage | Unit tests with an 80% line gate (`fail_under`) |
| Pinned Python | Interpreter version fixed in `.python-version`, floor in `requires-python` |
| lefthook | All hooks come from [aktin-github-scripts](https://github.com/aktin/aktin-github-scripts#git-hooks), see `lefthook.yml`. pre-commit formats and lints staged Python files, scans for secrets with gitleaks, lints staged workflows, Dockerfiles and shell scripts and rejects data files and large files, commit-msg enforces Conventional Commits and rejects oversized commits, pre-push runs `uv run mypy`, `uv run pytest` and `uv build` |
| GitHub workflows and rules | Checks on pull requests, CodeQL, dependency review, Scorecard, releases, Dependabot and the rulesets on `main` and release tags. Details in [.github/workflows/README.md](.github/workflows/README.md) |

## Project structure

```
src/python_starter/  the package (renamed by init.py)
tests/               pytest suite
.github/workflows/   verify, CodeQL, dependency review, Scorecard, release, described in the README there
SECURITY.md          security policy
scripts/init.py      one-time template initializer (removed after first run)
```

## License

Apache-2.0. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
