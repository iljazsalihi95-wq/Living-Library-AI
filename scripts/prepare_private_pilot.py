#!/usr/bin/env python3
"""Prepare a private, locally bundled pilot build without committing owner's photos.

Run from repository root:
    python3 scripts/prepare_private_pilot.py /path/to/Living_Library_22_Fotografite_Assets.zip --check-only
    python3 scripts/prepare_private_pilot.py /path/to/Living_Library_22_Fotografite_Assets.zip
    flutter pub get && flutter build apk --debug --split-per-abi

Never commit assets/story/frame_*.jpg or the modified pubspec.yaml.
"""
import hashlib
import stat
import re
import subprocess
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
            if (info.filename.startswith(("/", "\\")) or re.match(r"^[A-Za-z]:", info.filename)
                    or any(part in ("", ".", "..") for part in parts)):

                raise ValueError(f"Unsafe pilot archive path: {info.filename}")
            # ZIP entries can masquerade as images while carrying Unix symlink metadata.
            mode = (info.external_attr >> 16) & 0xFFFF
            if stat.S_IFMT(mode) == stat.S_IFLNK:
                raise ValueError(f"Symlink pilot frame is not supported: {name}")
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
    # Never overwrite or update pilot frames already tracked in Git.\n    # .gitignore does not protect files that were previously committed.\n    tracked = subprocess.run(\n        ["git", "ls-files", "--", "assets/story/"],\n        cwd=ROOT, check=True, capture_output=True, text=True,\n    ).stdout.splitlines()\n    tracked_frames = {Path(item).name for item in tracked} & set(frames)\n    if tracked_frames:\n        raise ValueError(\n            "Private pilot import refused: Git tracks pilot frames; "\n            "remove them from the Git index first (no photos were written)"\n        )\n    # Check every output path before modifying the Flutter manifest.
    # A rejected symlink must not leave a partially modified checkout.
    target = ROOT / "assets" / "story"
    # Reject symlinked output directories or frames before writing private bytes.
    # Otherwise a checkout could redirect the import outside the project.
    assets_dir = ROOT / "assets"
    if assets_dir.is_symlink() or target.is_symlink():
        raise ValueError("Private pilot output directory must not be a symlink")
    for name in frames:
        if (target / name).is_symlink():
            raise ValueError(f"Private pilot output must not be a symlink: {name}")
    # Validate the manifest and destination before writing anything.
    pubspec = ROOT / "pubspec.yaml"
    if pubspec.is_symlink():
        raise ValueError("Flutter manifest must not be a symlink")
    original = pubspec.read_text(encoding="utf-8")
    updated = original
    if "    - assets/story/" not in original:
        if "flutter:\n  uses-material-design: true" not in original:
            raise ValueError("Unknown pubspec layout")
        updated = original.replace(
            "flutter:\n  uses-material-design: true",
            "flutter:\n  uses-material-design: true\n  assets:\n    - assets/story/",
        )
    target.mkdir(parents=True, exist_ok=True)
    if updated != original:
        pubspec.write_text(updated, encoding="utf-8")
    for name, data in sorted(frames.items()):
        (target / name).write_bytes(data)
    print("Private bundle ready: 22 JPEGs. Do not commit photos or pubspec.yaml.")
    return 22


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != "--check-only"):
        raise SystemExit("Usage: python3 scripts/prepare_private_pilot.py PRIVATE_FRAMES.zip [--check-only]")
    prepare(Path(sys.argv[1]), check_only=len(sys.argv) == 3)
