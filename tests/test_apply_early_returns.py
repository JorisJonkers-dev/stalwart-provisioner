"""apply.sh runs under `set -e`, so an early return must be explicit.

A bare `return` returns the status of the last command executed. In the guard
form `[ -n "$x" ] || return`, that last command is the *failed* test, so the
function returns 1 and `set -e` aborts the whole reconcile -- with nothing
printed, because the guard is the quiet path.

That is not hypothetical. A manifest omitting the optional `dkim` block exited
1 immediately after the domain-settings step, which looked like a crash in
Stalwart rather than a skipped section, and the catch-all step below it never
ran.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GUARD = re.compile(r"^\s*\[.*\]\s*\|\|\s*return\s*$", re.MULTILINE)


def test_no_bare_early_return_in_apply() -> None:
    script = (ROOT / "scripts" / "apply.sh").read_text()
    offenders = [m.group(0).strip() for m in GUARD.finditer(script)]
    assert offenders == [], (
        "these guards use a bare `return`, which propagates the failed test's "
        "status and aborts the reconcile under set -e; use `return 0`:\n  "
        + "\n  ".join(offenders)
    )


def test_bootstrap_and_ruleset_scripts_too() -> None:
    for name in ("bootstrap.sh", "apply-ruleset.sh"):
        script = (ROOT / "scripts" / name).read_text()
        offenders = [m.group(0).strip() for m in GUARD.finditer(script)]
        assert offenders == [], f"{name} has bare early returns: {offenders}"
