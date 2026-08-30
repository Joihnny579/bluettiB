#!/usr/bin/env python3
"""Synchronize the repo version metadata from the single VERSION file."""

from __future__ import annotations

import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
version = (root / "VERSION").read_text(encoding="utf-8").strip()

manifest_path = root / "custom_components" / "bluetti_b" / "manifest.json"
manifest_data = json.loads(manifest_path.read_text(encoding="utf-8"))
manifest_data["version"] = version
manifest_path.write_text(json.dumps(manifest_data, indent=4) + "\n", encoding="utf-8")

readme_path = root / "README.md"
readme_text = readme_path.read_text(encoding="utf-8")
readme_text, replaced = re.subn(
    r"Current custom release: .*",
    f"Current custom release: {version}",
    readme_text,
    count=1,
)
if replaced != 1:
    raise RuntimeError("README version line not found")
readme_path.write_text(readme_text, encoding="utf-8")

print(f"Synced version to {version}")
