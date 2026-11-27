# Contributing

## Prerequisites

[uv](https://docs.astral.sh/uv/) is the package and environment manager. The
interpreter version is pinned in `.python-version`.

```sh
uv sync
uv run lefthook install
```

This installs dependencies, creates the venv, and sets up the git hooks.
The shared git hooks run with the `python3` on PATH and are pulled from the
repository configured under `remotes` in `lefthook.yml`, change `git_url` and
`ref` there to use another source.

## Development

```sh
uv run pytest        # unit tests with coverage
uv run mypy          # type check
uv run ruff check .  # lint
uv run ruff format . # format
uv build             # sdist + wheel
```

## Commits

Messages follow [Conventional Commits](https://www.conventionalcommits.org),
enforced by the shared `commit-msg` hook from
[aktin-github-scripts](https://github.com/aktin/aktin-github-scripts).

## Pull requests

Make sure `uv run ruff check .`, `uv run mypy`, and `uv run pytest` pass. The
pre-push hook runs those plus the build.

## Releases

Push a `vX.Y.Z` tag. The release workflow builds sdist and wheel, generates
the release notes, produces an SBOM and attestations, and publishes the
GitHub Release.
