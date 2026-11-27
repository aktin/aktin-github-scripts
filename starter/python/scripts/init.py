"""One-time template initializer. Fills in placeholders, renames the package, removes itself."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path

TOKENS = ("{{PROJECT_NAME}}", "{{REPO_SLUG}}", "{{DESCRIPTION}}", "{{OWNER}}")
FILES = ("pyproject.toml", "README.md", "NOTICE", ".github/CODEOWNERS", "tests/test_greet.py")
PLACEHOLDER_DIST = "python-starter"
PLACEHOLDER_MODULE = "python_starter"


def default_slug() -> str:
  """Guess the owner/repo slug from the git remote."""
  try:
    url = subprocess.run(["git", "remote", "get-url", "origin"], capture_output=True, text=True, check=True).stdout.strip()
  except (OSError, subprocess.CalledProcessError):
    return ""
  match = re.search(r"github\.com[:/](.+?)(?:\.git)?$", url)
  return match.group(1) if match else ""


def ask(question: str, default: str) -> str:
  """Prompt with a visible default."""
  suffix = f" [{default}]" if default else ""
  answer = input(f"{question}{suffix}: ").strip()
  return answer or default


def dist_name_of(name: str) -> str:
  """Normalize a project name to a distribution name."""
  return re.sub(r"^[-_.]+", "", re.sub(r"[^a-z0-9._-]+", "-", name.strip().lower()))


def authors_value(author: str) -> str:
  """Build the pyproject authors entry from 'Name <email>' or a bare name."""
  match = re.match(r"^(?P<name>.*?)\s*<(?P<email>.+)>$", author)
  if match:
    return f'[{{ name = "{match.group("name")}", email = "{match.group("email")}" }}]'
  return f'[{{ name = "{author}" }}]'


def main() -> int:
  slug = ask("Repository slug (owner/repo)", default_slug())
  _, _, name_guess = slug.partition("/")
  name = ask("Project name", name_guess)
  description = ask("Description", "")
  author = ask("Author (Name <email>)", "")
  owner = ask("Code owner (GitHub handle or team)", "akomii")

  dist_name = dist_name_of(name)
  module_name = dist_name.replace("-", "_").replace(".", "_")
  values = {
    "{{PROJECT_NAME}}": name,
    "{{REPO_SLUG}}": slug,
    "{{DESCRIPTION}}": description,
    "{{OWNER}}": owner,
  }

  for file in FILES:
    path = Path(file)
    if not path.exists():
      continue
    text = path.read_text(encoding="utf-8")
    for token in TOKENS:
      text = text.replace(token, values[token])
    text = text.replace('[{ name = "{{AUTHOR}}" }]', authors_value(author))
    text = text.replace(PLACEHOLDER_DIST, dist_name).replace(PLACEHOLDER_MODULE, module_name)
    path.write_text(text, encoding="utf-8")

  Path("src", PLACEHOLDER_MODULE).rename(Path("src", module_name))

  readme = Path("README.md")
  stripped = re.sub(r"<!-- template:start -->[\s\S]*?<!-- template:end -->\n?", "", readme.read_text(encoding="utf-8"))
  readme.write_text(stripped, encoding="utf-8")

  Path("scripts/init.py").unlink()
  if not any(Path("scripts").iterdir()):
    shutil.rmtree("scripts")

  print(
    "\nInitialized. Run 'uv sync' to refresh the lockfile, review the diff, then commit."
    " See the README 'Repository settings' section for the manual GitHub steps."
  )
  return 0


if __name__ == "__main__":
  sys.exit(main())
