# stalwart-provisioner

Schema-driven Stalwart account and DKIM provisioning for JorisJonkers-dev mail
deployments.

## What It Is

`stalwart-provisioner` provides an offline validation CLI, Stalwart apply
scripts, a GHCR runtime image, and a first-party deploy bundle fragment consumed
by the mail collection.

Consumers own their mail domains, accounts, DNS records, Vault/VSO objects,
Kubernetes manifests, and secret material. This repository owns the manifest
contract, Stalwart `apply` plan validation, reconcile scripts, image, and deploy
fragment.

## Local Use

```bash
uv sync --frozen
uv run ruff check .
uv run mypy
uv run pytest
```

Validate a v2 manifest:

```bash
bin/stalwart-provisioner validate manifest examples/manifest.valid.json
```

Validate a Stalwart `apply` NDJSON plan against the bundled management schema:

```bash
bin/stalwart-provisioner validate plan --schema schema/schema.min.json plan.ndjson.tmpl
```

Pack the deploy fragment locally:

```bash
python3 scripts/pack-deploy-bundle.py --version 0.0.0-local --out /tmp/stalwart-provisioner-deploy-bundle.tar
```

## Package

Runtime image:

```text
ghcr.io/jorisjonkers-dev/stalwart-provisioner:<version>
```

Deploy bundle:

```text
ghcr.io/jorisjonkers-dev/stalwart-provisioner-deploy-bundle:<version>
```

## Links

- [Organization profile](https://github.com/JorisJonkers-dev)
- [Security policy](https://github.com/JorisJonkers-dev/.github/security/policy)
- [License](./LICENSE)

Copyright (c) Joris Jonkers. Source available for viewing only; use, copying,
modification, redistribution, deployment, or reuse is not licensed. See
[LICENSE](./LICENSE).
