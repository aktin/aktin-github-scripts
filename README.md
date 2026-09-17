## aktin-github-scripts
This repository contains a collection of custom GitHub Actions and Github Workflows to automate various tasks. These scripts can be used in your GitHub repository to streamline your development and deployment processes.

### Folder Structure:

- **workflows/**: Contains reusable GitHub workflow files.
- **hooks/**: Contains pre-commit hooks to copy into your repository, with an example configuration.

### Workflows:

- **debian-build**: Builds a Debian package, runs integration tests, and uploads the `.deb` as a build artifact
- **debian-deploy**: Retrieves the `.deb` build artifact and adds it to a remote Debian repository using `reprepro`
- **maven-build-deploy**: Builds a Maven project, runs integration tests, and optionally deploys `.jar`/`.war`/`.ear` files to the AKTIN Maven repository

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

### Pre-Commit Hooks:

- **block-data-files**: Rejects staged data files (`.csv`, `.xlsx`, `.sql`, `.dcm`, `.hl7`, ...) outside `tests/fixtures/` to keep patient data out of the repository
- **check-large-files**: Rejects staged files larger than 500 KB
- **check-commit-size**: Rejects commits that change more than 200 lines in total (insertions plus deletions). Configure the limit with `args: ['--max-lines=300']`
- **check-commit-message**: Validates the commit message against the EU System Conventional Commit rules (`<type>(<scope>): <subject>`)

#### Usage:

The hooks are an offer for other repositories, nothing is enforced in this repository. Copy the `hooks/` folder into your repository and use `hooks/pre-commit-config.example.yaml` as your `.pre-commit-config.yaml`. Adjust the `entry` paths if you rename the folder. Then install the hooks once with `pre-commit install`.

### License:

This repository is licensed under GNU Affero General Public License v3.0. See the LICENSE file for more details.
