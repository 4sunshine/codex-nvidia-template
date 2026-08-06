# AGENTS.md

## Project goal

Replace this section with the project's purpose, current milestone, and
non-goals. Keep scope explicit enough that an agent can distinguish requested
implementation from future work.

## Architecture

Document component boundaries, important data flows, external services, and
the files that own each responsibility.

## Development environment

The committed Dev Container is the required environment for Codex, dependency
changes, application commands, tests, and agent work. Run project tooling
inside it.

Use `uv` for Python dependencies:

```bash
uv add PACKAGE
uv add --group dev PACKAGE
uv remove PACKAGE
uv sync
uv run COMMAND
```

Do not use `pip install`, `uv pip install`, global Python packages, or modify
system Python for project dependencies.

## Commands

```bash
uv sync --frozen
uv run python -m template_project
uv run python -m unittest discover -s tests
uv run python -m compileall src
```

Update this section when the real project introduces lint, formatting, type
checking, frontend, or integration commands. Do not report checks that the
repository does not actually provide.

## File and Git safety

- Inspect existing files and Git status before editing.
- Preserve unrelated user changes.
- Do not delete files or directories without explicit authorization.
- Do not use `git reset --hard`, `git clean`, history rewrites, or force pushes.
- Do not commit credentials, `.env`, SSH keys, model tokens, downloaded
  datasets, model weights, virtual environments, caches, or runtime state.
- Keep Git configuration repository-local unless the user explicitly requests
  a personal global setting.
- Use feature branches and reviewed pull requests for an established project.

## Dependency safety

- Keep dependencies minimal and explain each addition.
- Commit `pyproject.toml` and `uv.lock` together.
- Inspect lockfile changes and run relevant checks.
- Obtain approval before Git/URL/path/private-index dependencies, prereleases,
  broad upgrades, new download domains, or TLS/verification changes.
- Make missing OS libraries the smallest reviewed Dockerfile change.

## GPU, models, and datasets

- Request GPU access through Docker or the platform scheduler.
- Treat `CUDA_VISIBLE_DEVICES` as process selection, not isolation.
- Keep Hugging Face credentials outside the image and repository.
- Store reproducible downloads in the configured cache volume.
- Store unique trained artifacts in an explicitly backed-up location.
- Do not recursively change ownership of shared server caches.

## Completion requirements

Before finishing an implementation:

1. Run the relevant tests.
2. Run `uv run python -m compileall src`.
3. Report changed files, validation results, and anything not validated.

