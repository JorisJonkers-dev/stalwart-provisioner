#!/usr/bin/env python3
"""Validate and pack the repo-local deploy fragment into a deterministic tar."""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
import tarfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEPLOY_DIR = ROOT / "deploy"
DEPLOYMENT = DEPLOY_DIR / "deployment.yml"
ENV_FILES = (
    "runtime.env",
    "development.env",
    "staging.env",
    "production.env",
)
IMAGE_REPOSITORY = "ghcr.io/jorisjonkers-dev/stalwart-provisioner"
IMAGE_TOKEN = "${BUNDLE_VERSION}"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--out", required=True, type=Path)
    return parser.parse_args(argv)


def validate_deploy_dir() -> None:
    if not DEPLOYMENT.is_file():
        raise ValueError("deploy/deployment.yml is required")

    deployment = DEPLOYMENT.read_text(encoding="utf-8")
    required_fragments = [
        "apiVersion: deployment.jorisjonkers.dev/v2",
        "kind: DeploymentProject",
        "name: stalwart-provisioner",
        "fragment: true",
        f"{IMAGE_REPOSITORY}:{IMAGE_TOKEN}",
    ]
    for fragment in required_fragments:
        if fragment not in deployment:
            raise ValueError(f"deploy/deployment.yml missing {fragment!r}")

    for env_file in ENV_FILES:
        path = DEPLOY_DIR / env_file
        if not path.is_file():
            raise ValueError(f"deploy/{env_file} is required")
        validate_env_file(path)


def validate_env_file(path: Path) -> None:
    assignment = re.compile(r"^[A-Z][A-Z0-9_]*=.*$")
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if not assignment.fullmatch(line):
            relative = path.relative_to(ROOT)
            raise ValueError(f"{relative}:{line_number}: expected KEY=value")


def image_ref(version: str) -> str:
    return f"{IMAGE_REPOSITORY}:{version}"


def manifest(version: str) -> dict[str, Any]:
    return {
        "schemaVersion": "deployment.jorisjonkers.dev/bundle-manifest/v1",
        "name": "stalwart-provisioner",
        "version": version,
        "repo": "JorisJonkers-dev/stalwart-provisioner",
        "kind": "mail-fragment",
        "artifactType": "application/vnd.jorisjonkers.deployment.bundle.v1+tar",
        "images": [image_ref(version)],
        "files": ["deploy/deployment.yml", *(f"deploy/{env_file}" for env_file in ENV_FILES)],
    }


def tar_info(tar: tarfile.TarFile, source: Path, arcname: str) -> tarfile.TarInfo:
    info = tar.gettarinfo(str(source), arcname)
    info.uid = 0
    info.gid = 0
    info.uname = ""
    info.gname = ""
    info.mtime = 0
    return info


def add_file(tar: tarfile.TarFile, source: Path, arcname: str) -> None:
    info = tar_info(tar, source, arcname)
    with source.open("rb") as handle:
        tar.addfile(info, handle)


def add_rendered_deployment(tar: tarfile.TarFile, version: str) -> None:
    rendered = DEPLOYMENT.read_text(encoding="utf-8").replace(IMAGE_TOKEN, version)
    data = rendered.encode("utf-8")
    info = tar_info(tar, DEPLOYMENT, "deploy/deployment.yml")
    info.size = len(data)
    tar.addfile(info, io.BytesIO(data))


def add_bytes(tar: tarfile.TarFile, data: bytes, arcname: str) -> None:
    info = tarfile.TarInfo(arcname)
    info.size = len(data)
    info.uid = 0
    info.gid = 0
    info.uname = ""
    info.gname = ""
    info.mtime = 0
    tar.addfile(info, io.BytesIO(data))


def pack(version: str, out: Path) -> None:
    validate_deploy_dir()
    out.parent.mkdir(parents=True, exist_ok=True)

    with tarfile.open(out, "w") as tar:
        manifest_bytes = json.dumps(manifest(version), indent=2, sort_keys=True).encode("utf-8")
        add_bytes(tar, manifest_bytes + b"\n", "bundle-manifest.json")
        add_rendered_deployment(tar, version)
        for env_file in ENV_FILES:
            add_file(tar, DEPLOY_DIR / env_file, f"deploy/{env_file}")

    if out.stat().st_size == 0:
        raise ValueError(f"bundle is empty: {out}")


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        pack(args.version, args.out)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(out_message(args.out))
    return 0


def out_message(out: Path) -> str:
    return f"wrote {out}"


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
