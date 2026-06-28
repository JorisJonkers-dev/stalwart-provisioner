# Specification: Stalwart Provisioner

## Overview

JorisJonkers-dev/stalwart-provisioner defines schema-driven Stalwart mail account and DKIM provisioning as a reusable release artifact. The feature extracts the account, DKIM, bootstrap, reconcile, and plan-validation contract currently represented by the read-only reference material under `/workspace/personal-stack/infra/stalwart` into a product specification for this repository.

The product exists so consumer repositories can stop baking shared Stalwart provisioning behavior into their own source trees while still keeping domain-specific ownership local. Each consumer, including `personal-stack` and/or `website`, owns its mail domain, account list, DNS configuration, secret storage, and deployment wiring. This repository owns the versioned provisioning contract, the distributable GHCR runtime image, and the plan-validation command-line interface.

Distribution is intended to be artifact based: consumers reference a short, versioned coordinate such as `ghcr.io/jorisjonkers-dev/stalwart-provisioner:<version>` and pin that version through Renovate-managed updates. No doubled plugin-marker names are allowed in package, image, or artifact coordinates. `personal-stack` remains continuously auto-deployed and is not itself turned into a versioned product.

## User Scenarios

- Pinned consumer deployment: A platform operator updates a consumer repository from local Stalwart provisioning scripts to a pinned `stalwart-provisioner` artifact. The consumer keeps its own domain, account manifest, DNS records, Vault/VSO objects, and deployment manifests, while the shared image supplies the provisioning runtime and validation surface.
- Account secret source selection: A consumer declares service mail accounts using the v2 schema and selects one password source per account: environment variable, mounted file, or Vault-VSO-backed mounted file. Validation catches missing or ambiguous password references before deployment.
- Plan validation before rollout: A release maintainer validates generated or templated Stalwart `apply` plans against a local Stalwart management schema. Invalid object names, unknown fields, invalid enum values, malformed JSON, and invalid manifest references are reported before a live Stalwart server is touched.
- DKIM readiness for local DNS ownership: A consumer enables DKIM provisioning for its local mail domain and receives a deterministic provisioning outcome that supports Stalwart signing and DNS publication or local DNS record management without embedding consumer DNS data in this repository.
- Continuous deployment preservation: `personal-stack` consumes the released artifact at a pinned version while its existing continuously auto-deployed application model remains intact. Updating the provisioner does not require versioning `personal-stack` itself.

## Functional Requirements (FR-n)

- FR-1: The product MUST define a v2 provisioning schema for one primary Stalwart mail domain per manifest, including the domain name, public mail hostname, managed accounts, optional aliases, optional group memberships, DKIM provisioning intent, and references to consumer-local DNS and secret material.
- FR-2: The v2 schema MUST require every managed account to declare exactly one `passwordRef` variant and MUST reject account entries with no password reference or with more than one password reference.
- FR-3: The `passwordRef` union MUST support these variants: environment variable by name, mounted file by path, and Vault-VSO-backed mounted file by path plus consumer-local source identity.
- FR-4: The v2 schema MUST reject raw password values in manifests, plans, examples, and account declarations.
- FR-5: The v2 schema MUST keep consumer-owned values local by requiring domain names, account lists, DNS provider details, DNS zone records, Vault paths, and deployment-specific secret names to be supplied by the consumer repository rather than baked into the shared artifact.
- FR-6: Managed account declarations MUST be testable for unique local parts within the manifest, valid mail local-part syntax, aliases that do not collide with managed account local parts, and group references that resolve to declared managed accounts or documented pre-existing accounts.
- FR-7: Provisioning semantics MUST be idempotent: applying the same valid manifest repeatedly MUST NOT create duplicate accounts, duplicate aliases, duplicate group memberships, or duplicate DKIM declarations.
- FR-8: Account reconciliation MUST create missing managed accounts and update declared credentials, aliases, and group memberships, while avoiding deletion or recreation of existing mailbox data.
- FR-9: Account reconciliation MUST NOT manage accounts that are absent from the manifest, so user-managed mailboxes and consumer-local accounts remain outside the shared artifact boundary.
- FR-10: DKIM provisioning MUST support automatic Stalwart DKIM enablement for the declared domain and MUST make the resulting DNS requirements available to the consumer's local DNS process without storing consumer DNS zone content in this repository.
- FR-11: The runtime image MUST be published to GHCR as a versioned artifact and MUST contain the provisioning runtime and validation entrypoints without embedding any consumer-specific domain, account, DNS, or secret values.
- FR-12: Artifact coordinates MUST be short and stable, MUST include the artifact name only once, and MUST avoid doubled plugin-marker names or repeated package path segments.
- FR-13: Consumer repositories MUST be able to pin provisioner versions explicitly and receive Renovate-driven version updates without converting the consumer repository itself into a versioned artifact.
- FR-14: The plan-validation command-line interface MUST validate Stalwart `apply` NDJSON plans offline against a local Stalwart management schema and return a deterministic non-zero exit status for validation failures.
- FR-15: The plan-validation command-line interface MUST validate v2 provisioning manifests offline and report failures using field paths, account identifiers, and plan line numbers where applicable.
- FR-16: The validation surface MUST redact or omit secret values from all normal output, failure output, examples, and generated diagnostics.
- FR-17: The feature MUST preserve compatibility with the reference behavior that applies base Stalwart settings on a fresh datastore, reconciles domain settings on restart, and waits for Stalwart administrative readiness before provisioning.
- FR-18: The feature MUST provide a development bootstrap scenario that validates and applies a local, non-production manifest without requiring consumer production secrets.

## Success Criteria (SC-n, measurable)

- SC-1: Given a valid v2 manifest containing one account for each `passwordRef` variant, manifest validation exits `0` and produces no secret values in output.
- SC-2: Given invalid manifests with a missing `schemaVersion`, raw password value, duplicate managed account local part, alias collision, missing `passwordRef`, and multiple `passwordRef` variants, validation exits non-zero and reports at least one field path for each invalid case.
- SC-3: Given a valid Stalwart `apply` NDJSON plan and local schema, plan validation exits `0`; given an unknown object, unknown field, invalid enum, and malformed JSON line, plan validation exits non-zero and reports the affected line number.
- SC-4: Given the same valid manifest applied twice to an unchanged Stalwart datastore, the second run creates zero additional accounts, aliases, group memberships, and DKIM declarations.
- SC-5: Given an existing managed account with mailbox data, reconciliation updates credentials and declared metadata without deleting or recreating the account record.
- SC-6: Given a consumer repository scan after artifact adoption, no real domain names, account lists, DNS zone records, Vault paths, or deployment secret names from another consumer are required to consume the artifact.
- SC-7: A released image is addressable by a short GHCR coordinate with one artifact name occurrence, a version tag, and a digest; a Renovate rule can update that pinned version without changing consumer-owned domain or DNS files.
- SC-8: `personal-stack` can reference the provisioner through a pinned artifact coordinate while retaining continuous auto-deployment and without adding a `personal-stack` product version.
- SC-9: All validation and runtime diagnostics redact password values and secret file contents, with zero secret bytes emitted in standard output or standard error for the required error cases.
- SC-10: A local development bootstrap manifest can be validated and exercised with non-production placeholders and without requiring Vault, VSO, or public DNS access.

## Assumptions

- One v2 manifest manages one primary mail domain. Additional domains require a future schema revision or separate manifests.
- Stalwart exposes a local management schema suitable for offline validation of `apply` plans.
- Environment variables, mounted files, and Vault-VSO-backed mounted files cover the required password source models for initial consumers.
- Consumer repositories already own their DNS workflows and secret materialization workflows.
- GHCR is the distribution registry for the runtime image.
- Renovate is available in consuming repositories for pinned artifact updates.

## Edge Cases

- A password environment variable is unset or empty.
- A password file is missing, empty, unreadable, or contains a trailing newline.
- A Vault-VSO-backed file is declared but the corresponding consumer-local source identity is absent.
- Two managed accounts declare the same local part.
- An alias collides with another account local part or another alias.
- A group reference points to an account that is neither managed by the manifest nor documented as pre-existing.
- A consumer changes the mail domain while existing Stalwart account records remain tied to the previous domain.
- A Stalwart plan contains placeholders that are valid for templating but invalid as literal JSON without substitution.
- The local Stalwart schema is older or newer than the Stalwart server targeted by the consumer.
- Stalwart administrative readiness is delayed or the admin credential is invalid.
- DKIM keys or selectors already exist from a prior manual setup.
- A consumer attempts to include DNS zone data in the shared artifact instead of keeping it local.

## Key Entities

- Provisioning Manifest v2: Consumer-local declaration of the mail domain, public hostname, managed accounts, password references, DKIM intent, and validation inputs.
- Domain Profile: The primary Stalwart mail domain and public hostname that account addresses and DKIM behavior attach to.
- Managed Account: A service or user account intentionally reconciled by the provisioner, identified by local part and optional aliases or group memberships.
- Password Reference: A non-secret pointer to one password source, expressed as an environment variable, mounted file, or Vault-VSO-backed mounted file.
- DKIM Declaration: The desired Stalwart DKIM state for the declared domain and the DNS publication requirement that remains under consumer ownership.
- Plan File: A Stalwart `apply` NDJSON file or template validated before rollout.
- Plan-Validation CLI: Offline command-line interface that validates v2 manifests and Stalwart plans, reports deterministic failures, and redacts secrets.
- Runtime Image: GHCR-published image containing the provisioning runtime and validation entrypoints, versioned independently from consuming repositories.
- Consumer Repository: A repository such as `personal-stack` or `website` that pins the artifact and retains its own domain, accounts, DNS, Vault/VSO objects, and deployment manifests.

## Out of Scope

- Implementation code, release automation, container build definitions, and CI workflows for this specification pass.
- Modifying `/workspace/personal-stack` or `/workspace/website`.
- Moving consumer domain names, account lists, DNS zones, Vault paths, or deployment manifests into this repository.
- Managing mailbox data migration, backup restore, mailbox deletion, or account deletion.
- Owning public DNS zones or replacing consumer-local DNS workflows.
- Provisioning Vault, VSO, Kubernetes namespaces, Kubernetes Secrets, or registry pull credentials for consumers.
- Defining the full Renovate configuration for every consumer repository.
- Versioning `personal-stack` as a product artifact.
- Supporting multiple primary mail domains in a single v2 manifest.
- Supporting password sources beyond environment variables, mounted files, and Vault-VSO-backed mounted files.
