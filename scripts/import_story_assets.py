#!/usr/bin/env python3
"""Import the owner's 22 approved pilot frames from a local ZIP into Flutter assets.

Usage: python3 scripts/import_story_assets.py Living_Library_22_Fotografite_Assets.zip
No images are downloaded, generated, or replaced with placeholders.
"""
from pathlib import Path
from zipfile import ZipFile
import argparse
import hashlib

EXPECTED = [f"frame_{n:02d}.jpg" for n in range(1, 23)]
ASSETS = Path("assets/story")


def import_frames(archive: Path) -> None:
    with ZipFile(archive) as package:
        entries = {Path(name).name: name for name in package.namelist()
                   if name.lower().endswith((".jpg", ".jpeg"))}
        if set(entries) != set(EXPECTED):
            missing = sorted(set(EXPECTED) - set(entries))
            extra = sorted(set(entries) - set(EXPECTED))
            raise ValueError(f"Expected exactly 22 approved frames; missing={missing}; extra={extra}")
        verified = {}
        for name in EXPECTED:
            data = package.read(entries[name])
            if not (data.startswith(bytes.fromhex("ffd8")) and data.endswith(bytes.fromhex("ffd9"))):
                raise ValueError(f"Invalid JPEG file: {name}")
            verified[name] = data
    ASSETS.mkdir(parents=True, exist_ok=True)
    for name, data in verified.items():
        (ASSETS / name).write_bytes(data)
        print(f"{ASSETS / name} {len(data)} bytes sha256={hashlib.sha256(data).hexdigest()}")
    print("Imported all 22 verified pilot frames.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    import_frames(parser.parse_args().archive)
