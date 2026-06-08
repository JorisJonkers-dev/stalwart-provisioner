#!/usr/bin/env python3
"""Compatibility wrapper for validating Stalwart apply NDJSON plans."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    cli = root / "bin" / "stalwart-provisioner"
    if len(sys.argv) < 3:
        return subprocess.call([str(cli), "validate-plan", "--help"])
    env = os.environ.copy()
    return subprocess.call([str(cli), "validate-plan", "--schema", sys.argv[1], *sys.argv[2:]], env=env)


if __name__ == "__main__":
    sys.exit(main())
