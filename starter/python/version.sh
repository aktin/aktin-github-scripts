# Asks for the Python version and sets it in .python-version, as the floor in
# requires-python and as the ruff target. Sourced by new-repo.sh in the new
# repository.
python_version=$(ask "Python version" "$(cat .python-version)" "The interpreter uv installs, for example 3.14.6. Its minor version also becomes the lowest supported one")
[[ "$python_version" =~ ^3\.([0-9]+)(\.[0-9]+)?$ ]] || fail "$python_version is not a Python 3 version like 3.14.6"
minor="${BASH_REMATCH[1]}"
echo "$python_version" >.python-version
sed -i -e "s/^requires-python = .*/requires-python = \">=3.$minor\"/" \
  -e "s/^target-version = .*/target-version = \"py3$minor\"/" pyproject.toml
