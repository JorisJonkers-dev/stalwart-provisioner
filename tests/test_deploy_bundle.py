from __future__ import annotations

import json
import subprocess
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_deploy_bundle_pack_contains_manifest_and_fragment(tmp_path: Path) -> None:
    bundle = tmp_path / "stalwart-provisioner-deploy-bundle.tar"

    result = subprocess.run(
        [
            "python3",
            "scripts/pack-deploy-bundle.py",
            "--version",
            "0.0.0-test",
            "--out",
            str(bundle),
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )

    assert result.returncode == 0, result.stdout
    assert bundle.stat().st_size > 0

    with tarfile.open(bundle, "r") as tar:
        names = sorted(tar.getnames())
        assert names == [
            "bundle-manifest.json",
            "deploy/deployment.yml",
            "deploy/development.env",
            "deploy/production.env",
            "deploy/runtime.env",
            "deploy/staging.env",
        ]

        manifest_file = tar.extractfile("bundle-manifest.json")
        assert manifest_file is not None
        manifest = json.loads(manifest_file.read().decode("utf-8"))

        deployment_file = tar.extractfile("deploy/deployment.yml")
        assert deployment_file is not None
        deployment = deployment_file.read().decode("utf-8")

    assert manifest["version"] == "0.0.0-test"
    assert manifest["kind"] == "mail-fragment"
    assert manifest["images"] == ["ghcr.io/jorisjonkers-dev/stalwart-provisioner:0.0.0-test"]
    assert "ghcr.io/jorisjonkers-dev/stalwart-provisioner:0.0.0-test" in deployment
    assert "${BUNDLE_VERSION}" not in deployment
