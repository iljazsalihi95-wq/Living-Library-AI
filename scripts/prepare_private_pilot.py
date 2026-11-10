#!/usr/bin/env python3
"""Prepare a private, locally bundled pilot build without committing owner's photos.

Run from repository root:
    python3 scripts/prepare_private_pilot.py /path/to/Living_Library_22_Fotografite_Assets.zip --check-only
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


def prepare(zip_path: Path, check_only: bool = False) -> int:
    with zipfile.ZipFile(zip_path) as archive:
        frames = {}
        total_uncompressed = 0
        for info in archive.infolist():
            name = Path(info.filename).name
            if not PATTERN.fullmatch(name):
                continue
            # Never accept ambiguous archive paths or encrypted image entries.
            parts = info.filename.replace("\\", "/").split("/")
            if info.filename.startswith(("/", "\\")) or any(part in ("", ".", "..") for part in parts):
                raise ValueError(f"Unsafe pilot archive path: {info.filename}")
            if info.flag_bits & 0x1:
                raise ValueError(f"Encrypted pilot frame is not supported: {name}")
            if info.is_dir() or info.file_size == 0:
                raise ValueError(f"Empty or invalid pilot frame: {name}")
            if name in frames or info.file_size > 20 * 1024 * 1024:
                raise ValueError(f"Duplicate or oversized frame: {name}")
            total_uncompressed += info.file_size
            if total_uncompressed > 22 * 20 * 1024 * 1024:
                raise ValueError("Pilot archive exceeds the allowed image size budget")
            if info.compress_size == 0 or info.file_size > 200 * info.compress_size:
                raise ValueError("Suspicious JPEG compression ratio")
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
    if check_only:
        print("Private archive verified: 22 distinct JPEGs. No files were written.")
        return 22
    # Validate the Flutter manifest before touching any private photo files.
    pubspec = ROOT / "pubspec.yaml"
    original = pubspec.read_text(encoding="utf-8")
    if "    - assets/story/" not in original:
        if "flutter:\n  uses-material-design: true" not in original:
            raise ValueError("Unknown pubspec layout")
        pubspec.write_text(original.replace(
            "flutter:\n  uses-material-design: true",
            "flutter:\n  uses-material-design: true\n  assets:\n    - assets/story/",
        ), encoding="utf-8")
    target = ROOT / "assets" / "story"
    target.mkdir(parents=True, exist_ok=True)
    for name, data in sorted(frames.items()):
        (target / name).write_bytes(data)
    print("Private bundle ready: 22 JPEGs. Do not commit photos or pubspec.yaml.")
    return 22


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != "--check-only"):
        raise SystemExit("Usage: python3 scripts/prepare_private_pilot.py PRIVATE_FRAMES.zip [--check-only]")
    prepare(Path(sys.argv[1]), check_only=len(sys.argv) == 3)
