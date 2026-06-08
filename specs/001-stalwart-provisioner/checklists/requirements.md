# Requirements Checklist: Stalwart Provisioner

## Specification Shape

- [x] Overview explains what the feature provides and why it exists.
- [x] User scenarios describe consumer, maintainer, and operator outcomes.
- [x] Functional requirements are numbered and testable.
- [x] Success criteria are numbered and measurable.
- [x] Assumptions and edge cases are explicit.
- [x] Key entities define the contract vocabulary.
- [x] Out-of-scope items bound this pass to specification artifacts only.

## Requirement Quality

- [x] The v2 schema requirement includes the password reference union.
- [x] The password reference union covers environment variable, mounted file, and Vault-VSO-backed mounted file sources.
- [x] Raw secret values are prohibited by requirement.
- [x] Consumer-owned domain, account, DNS, and secret material remain local to consuming repositories.
- [x] GHCR artifact distribution and version pinning are specified.
- [x] Short artifact coordinates and no doubled plugin-marker names are specified.
- [x] Renovate-pinned consumption is specified without versioning `personal-stack`.
- [x] The validation command-line interface has offline plan and manifest validation requirements.
- [x] DKIM provisioning is specified without taking ownership of consumer DNS zones.

## Scope Guardrails

- [x] No implementation files are requested by the specification.
- [x] No changes are required in read-only reference repositories.
- [x] No consumer-specific domains, account lists, DNS zones, or Vault paths are required in this repository.
- [x] Multiple-domain support is deferred outside the initial v2 manifest scope.
