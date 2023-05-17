## aktin-github-actions
This repository contains a collection of custom GitHub Actions to automate various tasks and workflows. These actions can be used in your GitHub workflows to streamline your development and deployment processes.

### Actions:

- python-ql : Performs linting, code formatting, security scanning, and custom integration testing for Python projects.
- python-version-tagging : Checks a specified Python script for a version change in its metadata, and if detected, tags the previous commit with the last version and pushes this new tag to the repository

### Usage:

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
        uses: aktin/aktin-github-actions/action1@main
        with:
          parameter1: 'value1'
          parameter2: 'value2 value3 value4'
      # Add more steps...
```      

### License:

This repository is licensed under GNU Affero General Public License v3.0. See the LICENSE file for more details.
