# Agents

Guidance for any coding agent working in this repository. It holds schema-driven Stalwart account and DKIM provisioning: a validation CLI, apply scripts, a runtime image and a deploy fragment.

The repo's agent contract is [CLAUDE.md](CLAUDE.md); the estate-wide conventions are at https://github.com/JorisJonkers-dev/workspace/blob/main/CLAUDE.md.

## Build and test

- `uv sync --frozen`
- `uv run ruff check .`
- `uv run mypy`
- `uv run pytest`
- Validate an example manifest: `bin/stalwart-provisioner validate manifest examples/manifest.valid.json`
