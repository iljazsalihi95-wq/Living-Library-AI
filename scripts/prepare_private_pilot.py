#!/usr/bin/env python3
"""Prepare a private, locally bundled pilot build without committing owner's photos.

Run from repository root:
    python3 scripts/prepare_private_pilot.py /path/to/Living_Library_22_Fotografite_Assets.zip
    flutter pub get && flutter build apk --debug --split-per-abi

Never commit assets/story/frame_*.jpg or the modified pubspec.yaml.
"""
import hashlib
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERN = re.compile(r"frame_(0[1-9]|1[0-9]|2[0-2])\.jpg")


def prepare(zip_path: Path) -> int:
    with zipfile.ZipFile(zip_path) as archive:
        frames = {}
        for info in archive.infolist():
            name = Path(info.filename).name
            if not PATTERN.fullmatch(name):
                continue
            if name in frames or info.file_size > 20 * 1024 * 1024:
                raise ValueError(f"Duplicate or oversized frame: {name}")
            data = archive.read(info)
            if len(data) < 4 or data[:2] != b"\xff\xd8" or data[-2:] != b"\xff\xd9":
                raise ValueError(f"Invalid JPEG: {name}")
            frames[name] = data
    if len(frames) != 22:
        raise ValueError(f"Expected 22 frames, found {len(frames)}")
    # Detect accidental reuse of the same photograph under different frame names.
    hashes = [hashlib.sha256(data).digest() for data in frames.values()]
    if len(set(hashes)) != 22:
        raise ValueError("Pilot contains duplicate JPEG content; 22 distinct frames required")
    target = ROOT / "assets" / "story"
    target.mkdir(parents=True, exist_ok=True)
    for name, data in sorted(frames.items()):
        (target / name).write_bytes(data)
    pubspec = ROOT / "pubspec.yaml"
    original = pubspec.read_text(encoding="utf-8")
    if "    - assets/story/" not in original:
        if "flutter:\n  uses-material-design: true" not in original:
            raise ValueError("Unknown pubspec layout")
        pubspec.write_text(original.replace(
            "flutter:\n  uses-material-design: true",
            "flutter:\n  uses-material-design: true\n  assets:\n    - assets/story/",
        ), encoding="utf-8")
    print("Private bundle ready: 22 JPEGs. Do not commit photos or pubspec.yaml.")
    return 22


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 scripts/prepare_private_pilot.py PRIVATE_FRAMES.zip")
    prepare(Path(sys.argv[1]))
