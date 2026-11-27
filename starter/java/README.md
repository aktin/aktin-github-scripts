# {{PROJECT_NAME}}

[![Verify](https://github.com/{{REPO_SLUG}}/actions/workflows/verify.yml/badge.svg)](https://github.com/{{REPO_SLUG}}/actions/workflows/verify.yml)
[![CodeQL](https://github.com/{{REPO_SLUG}}/actions/workflows/scan-codeql.yml/badge.svg)](https://github.com/{{REPO_SLUG}}/actions/workflows/scan-codeql.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/{{REPO_SLUG}}/badge)](https://securityscorecards.dev/viewer/?uri=github.com/{{REPO_SLUG}})
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)
<!-- profile:release:start -->
[![Release](https://img.shields.io/github/v/release/{{REPO_SLUG}})](https://github.com/{{REPO_SLUG}}/releases)
<!-- profile:release:end -->

# {{DESCRIPTION}}

## Stack

<!-- profile:release:start -->
Maven multi-module (Java 25, `mvnw` pinned), Spring Boot app module, Spotless with the Eclipse formatter, Checkstyle, JUnit 5 with a JaCoCo coverage gate, lefthook with shared hooks from aktin-github-scripts, tag-driven releases via git-cliff, and a hardened GitHub Actions pipeline (CI, CodeQL, Scorecard, dependency review, SBOM, build attestations).
<!-- profile:release:end -->
<!-- profile:no-release:start -->
Maven multi-module (Java 25, `mvnw` pinned), Spring Boot app module, Spotless with the Eclipse formatter, Checkstyle, JUnit 5 with a JaCoCo coverage gate, lefthook with shared hooks from aktin-github-scripts, and a hardened GitHub Actions pipeline (CI, CodeQL, Scorecard, dependency review).
<!-- profile:no-release:end -->

## Getting started

Prerequisites: Java 25 on PATH (Maven comes through the wrapper) and the [lefthook](https://lefthook.dev) binary for the git hooks (`apt install lefthook`, `brew install lefthook`, or a release download). The shared git hooks need `python3`, `gitleaks`, `actionlint`, `hadolint` and `shellcheck` on PATH. A missing tool fails the commit. actionlint, hadolint and shellcheck are only called when a workflow file, Dockerfile or shell script is staged.

```sh
./mvnw verify                    # full gate: format check, checkstyle, tests + coverage, build
./mvnw spotless:apply            # format
./mvnw test                      # unit tests
./mvnw -pl app spring-boot:run   # run the app
lefthook install                 # git hooks (one-time)
```

The coverage report lands in `app/target/site/jacoco/index.html`.

Commits must follow [Conventional Commits](https://www.conventionalcommits.org), enforced by the commit-msg hook:

```
<type>(<optional scope>): <subject>
```

Allowed types are `feat fix docs style refactor perf test chore`, the subject starts lowercase and has no trailing period, every line of the message stays at most 100 characters.
<!-- profile:release:start -->

To cut a release, check out the commit on `main` that you want to release, tag it `vX.Y.Z` and push the tag. Example for version 1.2.3:

```sh
git tag v1.2.3
git push origin v1.2.3
```

The tag starts `release.yml`, see [Workflows](.github/workflows/README.md#workflows).
<!-- profile:release:end -->

## Repository settings

The repository was created with `new-repo.sh` from [aktin-github-scripts](https://github.com/aktin/aktin-github-scripts) which also applied the settings profile `{{PROFILE}}.json`. To apply it again, run from the root of aktin-github-scripts:

```sh
repo-settings/apply.sh {{REPO_SLUG}} repo-settings/{{PROFILE}}.json
```

<!-- profile:release:start -->
The code owners in `.github/CODEOWNERS` must approve every pull request into `main`.
<!-- profile:release:end -->
<!-- profile:no-release:start -->
GitHub asks the code owners in `.github/CODEOWNERS` for a review of every pull request into `main`. The merge does not wait for it.
<!-- profile:no-release:end -->

<!-- profile:release:start -->
### Branch `dev` for releases

Features collect on `dev`, `dev` goes to `main` and `main` mirrors the released state. Dependabot opens its version updates against `dev`, see `target-branch` in `.github/dependabot.yml`.

<!-- profile:release:end -->
## How the infra works

| Component | What it does |
| --- | --- |
| Maven multi-module | Parent pom + `app` module, add modules via `<module>` entries |
| mvnw wrapper | Maven version pinned in `.mvn/wrapper/maven-wrapper.properties` |
<!-- profile:release:start -->
| `${revision}` versioning | Single version property in the parent pom. It stays at `0.0.0`, the release workflow sets the version |
<!-- profile:release:end -->
<!-- profile:no-release:start -->
| `${revision}` versioning | Single version property in the parent pom, `0.0.0` |
<!-- profile:no-release:end -->
| Spotless | Eclipse formatter (`eclipse-formatter.xml`: 2-space indent, 150 columns), `check` bound to the build, `apply` in the pre-commit hook |
| Checkstyle | Correctness and naming rules only, no formatting rules |
| JUnit 5 + JaCoCo | Unit tests with an 80% line gate on `verify`, Boot entry point excluded |
| lefthook | All hooks come from [aktin-github-scripts](https://github.com/aktin/aktin-github-scripts#git-hooks), see `lefthook.yml`. pre-commit formats and lints staged Java files, scans for secrets with gitleaks, lints staged workflows, Dockerfiles and shell scripts and rejects data files and large files, commit-msg enforces Conventional Commits and rejects oversized commits, pre-push runs `mvnw verify` |
<!-- profile:release:start -->
| GitHub workflows and rules | Checks on pull requests, CodeQL, dependency review, Scorecard, releases, Dependabot and the rulesets on `main` and release tags. Details in [.github/workflows/README.md](.github/workflows/README.md) |
<!-- profile:release:end -->
<!-- profile:no-release:start -->
| GitHub workflows and rules | Checks on pull requests, CodeQL, dependency review, Scorecard, Dependabot and the ruleset on `main`. Details in [.github/workflows/README.md](.github/workflows/README.md) |
<!-- profile:no-release:end -->

## Project structure

```
app/                   Spring Boot application module, package org.aktin.{{MODULE}}
<!-- profile:release:start -->
.github/workflows/     verify, CodeQL, dependency review, Scorecard, release, described in the README there
<!-- profile:release:end -->
<!-- profile:no-release:start -->
.github/workflows/     verify, CodeQL, dependency review, Scorecard, described in the README there
<!-- profile:no-release:end -->
checkstyle.xml         correctness rules (formatting lives in Spotless)
eclipse-formatter.xml  Spotless formatter settings (2-space indent, 150 columns)
<!-- profile:release:start -->
SECURITY.md            security policy
<!-- profile:release:end -->
```

## License

Apache-2.0. See [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
