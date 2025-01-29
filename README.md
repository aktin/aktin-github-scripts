## aktin-github-scripts
This repository contains a collection of custom GitHub Actions and Github Workflows to automate various tasks. These scripts can be used in your GitHub repository to streamline your development and deployment processes.

### Folder Structure:

- **workflows/**: Contains reusable GitHub workflow files.
- **actions/**: Contains custom actions, each in its own subfolder.

### Actions:

- **python-ql**: Performs linting, code formatting, security scanning, and custom integration testing for Python projects

#### Usage:

To use any of the actions in your GitHub workflows, you can reference this repository and the specific action within your workflow YAML file.

```yaml
# .github/workflows/my-workflow.yml
name: My Workflow
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v2

      - name: Run action1
        uses: aktin/aktin-github-scripts/action1@main
        with:
          parameter1: 'value1'
          parameter2: 'value2 value3 value4'
```

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

### License:

This repository is licensed under GNU Affero General Public License v3.0. See the LICENSE file for more details.
