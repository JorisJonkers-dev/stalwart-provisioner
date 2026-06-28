# stalwart-provisioner

Schema-driven Stalwart account and DKIM provisioning, packaged as a reusable
runtime image and offline validation CLI.

Consumers keep their own mail domain, accounts, DNS records, Vault/VSO objects,
Kubernetes manifests, and secret material. This repository owns the versioned
manifest contract, the Stalwart `apply` plan validator, the reconcile scripts,
and the image published as:

```text
ghcr.io/jorisjonkers-dev/stalwart-provisioner:<version>
```

## Manifest Contract

The v2 manifest schema is in
[`schema/provisioning-manifest.v2.schema.json`](schema/provisioning-manifest.v2.schema.json).
Each manifest manages one primary Stalwart mail domain and a list of managed
accounts. Every account must declare exactly one password source:

- `passwordRef.envVar`
- `passwordRef.file`
- `passwordRef.vaultPath` with `file` and `sourceIdentity`

Raw password values are rejected. File and Vault-backed references are mounted
file paths; Vault identity and path values remain consumer-owned configuration.

See [`examples/manifest.valid.json`](examples/manifest.valid.json) for a
non-secret fixture covering all password reference variants.

## Validation

Validate a v2 manifest:

```sh
bin/stalwart-provisioner validate manifest examples/manifest.valid.json
```

Validate password sources as part of an apply-time check:

```sh
bin/stalwart-provisioner validate manifest --check-password-sources manifest.json
```

Validate a Stalwart `apply` NDJSON plan against the bundled management schema:

```sh
bin/stalwart-provisioner validate plan --schema schema/schema.min.json plan.ndjson.tmpl
```

The compatibility wrapper remains available:

```sh
schema/validate-plan.py schema/schema.min.json plan.ndjson.tmpl
```

## Runtime

The image contains these entrypoints:

- `stalwart-provisioner`: offline validation CLI
- `stalwart-provisioner-apply`: validate and reconcile a consumer manifest
- `stalwart-provisioner-bootstrap`: run the apply path once for local
  development

Required apply-time environment:

```sh
STALWART_URL=http://127.0.0.1:8080
STALWART_USER=admin
STALWART_PASSWORD=...
STALWART_MANIFEST=/etc/stalwart-provisioner/manifest.json
```

The apply path is idempotent: it creates the initial domain/listener plan only
when the manifest domain is absent, then updates declared credentials, aliases,
group memberships, default hostname/domain settings, and DKIM management. It
does not delete or recreate existing mailbox data and does not manage accounts
absent from the manifest.
