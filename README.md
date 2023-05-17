## aktin-github-actions
This repository contains a collection of custom GitHub Actions to automate various tasks and workflows. These actions can be used in your GitHub workflows to streamline your development and deployment processes.

### Actions:

- python-ql : Performs linting, code formatting, security scanning, and custom integration testing for Python projects.

### Usage:

To use any of the actions in your GitHub workflows, you can reference this repository and the specific action within your workflow YAML file.

```yaml
# .github/workflows/main.yml
name: My Workflow
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v2
      
      - name: Run aktin's action1
        uses: aktin/aktin-github-actions/.template/workflows/action1.yml
        with:
          parameter1: value1
          parameter2: value2
      # Add more steps...
```      

### License:

This repository is licensed under GNU Affero General Public License v3.0. See the LICENSE file for more details.