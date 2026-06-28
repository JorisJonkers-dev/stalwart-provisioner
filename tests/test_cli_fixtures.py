from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "stalwart-provisioner"
SCHEMA = ROOT / "schema" / "schema.min.json"


def run_cli(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(CLI), *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )


def test_valid_manifest_fixtures_pass() -> None:
    result = run_cli(
        "validate",
        "manifest",
        "examples/manifest.valid.json",
        "examples/dev-manifest.json",
    )

    assert result.returncode == 0, result.stdout


def test_valid_plan_fixtures_pass() -> None:
    result = run_cli(
        "validate",
        "plan",
        "--schema",
        str(SCHEMA),
        "examples/plan.valid.ndjson",
        "plan.ndjson.tmpl",
    )

    assert result.returncode == 0, result.stdout


@pytest.mark.parametrize(
    "fixture",
    sorted((ROOT / "tests" / "fixtures" / "invalid-manifests").glob("*.json")),
)
def test_invalid_manifest_fixtures_fail(fixture: Path) -> None:
    result = run_cli("validate", "manifest", str(fixture.relative_to(ROOT)))

    assert result.returncode != 0
    assert "FAIL" in result.stdout


@pytest.mark.parametrize(
    "fixture",
    sorted((ROOT / "tests" / "fixtures" / "invalid-plans").glob("*.ndjson")),
)
def test_invalid_plan_fixtures_fail(fixture: Path) -> None:
    result = run_cli(
        "validate",
        "plan",
        "--schema",
        str(SCHEMA),
        str(fixture.relative_to(ROOT)),
    )

    assert result.returncode != 0
    assert "FAIL" in result.stdout
