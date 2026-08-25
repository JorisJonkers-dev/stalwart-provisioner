"""Every field the manifest schema declares must be read by some implementation.

The schema is the contract the manifest author writes against, but nothing tied
it to the code that reconciles. `managedAccounts[].description` was declared in
the schema and accepted by the validator's allowed-key set while no code path
ever wrote it, so a manifest carrying a description validated clean, reconciled
"successfully", and left the account's description null forever.

Stalwart's `apply` compounds this: an update naming a property the server does
not recognise still reports `1 updated, 0 failed`, so a dropped field produces
no error at either end.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = ROOT / "schema" / "provisioning-manifest.v2.schema.json"

# Only the files that *act* on a field count as consumers. The validator is
# deliberately excluded: its allowed-key set names every field in the schema, so
# including it would make this gate pass for any declared field -- which is how
# `description` stayed orphaned.
SOURCES = (
    ROOT / "plan.ndjson.tmpl",
    *sorted((ROOT / "scripts").glob("*.sh")),
)

# Fields that exist for validation alone and are correctly absent from reconcile.
# `preExistingAccounts` is validated but never acted on: apply.sh never destroys
# accounts, so declaring an unmanaged account has no reconcile-time effect.
VALIDATOR_ONLY = {"schemaVersion", "preExistingAccounts"}


def _declared_fields(node: dict[str, Any], path: list[str]) -> list[tuple[str, str]]:
    found = []
    for key, value in (node.get("properties") or {}).items():
        found.append((".".join([*path, key]), key))
        if isinstance(value, dict):
            found += _declared_fields(value, [*path, key])
            items = value.get("items")
            if isinstance(items, dict):
                found += _declared_fields(items, [*path, key, "[]"])
    return found


def test_every_declared_field_has_a_consumer() -> None:
    schema = json.loads(SCHEMA.read_text())
    haystack = "\n".join(p.read_text() for p in SOURCES if p.exists())

    orphans = [
        dotted
        for dotted, key in _declared_fields(schema, [])
        if key not in haystack and key not in VALIDATOR_ONLY
    ]
    assert orphans == [], (
        "these manifest fields are declared in the schema but never read by the "
        "reconcile scripts or the plan template, so a manifest setting them "
        "validates clean and silently does nothing:\n  "
        + "\n  ".join(orphans)
    )


def test_account_description_reaches_stalwart() -> None:
    """The specific regression: description must be sent in an Account update."""
    apply_sh = (ROOT / "scripts" / "apply.sh").read_text()
    assert "description:$description" in apply_sh, (
        "reconcile_account_metadata must add description to the Account update "
        "payload; without it the manifest field is silently dropped"
    )
