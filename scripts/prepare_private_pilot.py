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
            # Reject every unrelated archive entry, including documents and
            # hidden files. Only the 22 named JPEGs may enter this private build.
            if not PATTERN.fullmatch(name):
                raise ValueError(f"Unexpected entry in private pilot archive: {info.filename}")
            # Never accept ambiguous archive paths or encrypted image entries.
            parts = info.filename.replace("\\", "/").split("/")
            if (info.filename.startswith(("/", "\\")) or re.match(r"^[A-Za-z]:", info.filename)
                    or len(parts) != 1 or any(part in ("", ".", "..") for part in parts)):
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
            if len(data) < 128 or data[:2] != b"\xff\xd8" or data[-2:] != b"\xff\xd9":
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
    # Never overwrite or update pilot frames already tracked in Git.
    # .gitignore does not protect files that were previously committed.
    tracked = subprocess.run(
        ["git", "ls-files", "--", "assets/story/"],
        cwd=ROOT, check=True, capture_output=True, text=True,
    ).stdout.splitlines()
    tracked_frames = {Path(item).name for item in tracked} & set(frames)
    if tracked_frames:
        raise ValueError(
            "Private pilot import refused: Git tracks pilot frames; "
            "remove them from the Git index first (no photos were written)"
        )
    # Check every output path before modifying the Flutter manifest.
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
    # Refuse a checkout with other story photographs. A Flutter asset-directory
    # declaration bundles every file in this directory, not only frame_01..22.
    # Check before writing to avoid accidentally packaging unrelated private data.
    if target.exists():
        if not target.is_dir():
            raise ValueError("Private pilot output path is not a directory")
        # Flutter bundles every file under a declared asset directory.
        # Reject non-image documents, hidden files, and subdirectories too:
        # they could otherwise be copied into the private APK unnoticed.
        unexpected = sorted(
            item.name for item in target.iterdir()
            if item.name not in frames or not item.is_file()
        )
        if unexpected:
            raise ValueError(
                "Private pilot import refused: unexpected story images already exist: "
                + ", ".join(unexpected)
            )
        # Preserve previous private imports rather than silently overwriting them.
        existing = sorted(item.name for item in target.iterdir())
        if existing:
            raise ValueError(
                "Private pilot import refused: existing private frames must be "
                "backed up and cleared manually before re-import (no files written)"
            )
    # Validate the manifest and destination before writing anything.
    pubspec = ROOT / "pubspec.yaml"
    if pubspec.is_symlink():
        raise ValueError("Flutter manifest must not be a symlink")
    original = pubspec.read_text(encoding="utf-8")
    updated = original
    # Inspect only the actual top-level Flutter block, not commented examples
    # or similarly named assets in another YAML section.
    flutter_lines = original.splitlines(keepends=True)
    flutter_index = next(
        (i for i, line in enumerate(flutter_lines)
         if line.rstrip() == "flutter:"), None,
    )
    if flutter_index is None:
        raise ValueError("Missing top-level Flutter configuration")
    if sum(line.rstrip() == "flutter:" for line in flutter_lines) != 1:
        raise ValueError("Ambiguous Flutter manifest: multiple top-level flutter blocks")
    section_end = next(
        (i for i in range(flutter_index + 1, len(flutter_lines))
         if flutter_lines[i].strip()
         and not flutter_lines[i].startswith((" ", "#", "\t"))),
        len(flutter_lines),
    )
    assets_index = next(
        (i for i in range(flutter_index + 1, section_end)
         if flutter_lines[i].startswith("  assets:")), None,
    )
    if sum(line.startswith("  assets:") for line in flutter_lines[flutter_index + 1:section_end]) > 1:
        raise ValueError("Ambiguous Flutter manifest: multiple assets blocks")
    # Only a real list entry within the Flutter assets subsection counts.
    asset_end = section_end if assets_index is None else next(
        (i for i in range(assets_index + 1, section_end)
         if flutter_lines[i].strip()
         and not flutter_lines[i].startswith(("    ", "#"))),
        section_end,
    )
    registered = assets_index is not None and any(
        line.strip() == "- assets/story/" and not line.lstrip().startswith("#")
        for line in flutter_lines[assets_index + 1:asset_end]
    )
    if not registered:
        if assets_index is not None:
            flutter_lines.insert(assets_index + 1, "    - assets/story/\n")
        else:
            flutter_lines.insert(section_end, "  assets:\n    - assets/story/\n")
        updated = "".join(flutter_lines)
    # Write the manifest last: a failed image write must never leave Flutter
    # configured to package an incomplete private pilot. Roll back only files
    # created by this import; existing imports were rejected above.
    target.mkdir(parents=True, exist_ok=True)
    written = []
    try:
        for name, data in sorted(frames.items()):
            destination = target / name
            with destination.open("xb") as output:
                written.append(destination)
                output.write(data)
        if updated != original:
            pubspec.write_text(updated, encoding="utf-8")
    except Exception:
        for destination in written:
            destination.unlink(missing_ok=True)
        raise
    print("Private bundle ready: 22 JPEGs. Do not commit photos or pubspec.yaml.")
    return 22


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3) or (len(sys.argv) == 3 and sys.argv[2] != "--check-only"):
        raise SystemExit("Usage: python3 scripts/prepare_private_pilot.py PRIVATE_FRAMES.zip [--check-only]")
    prepare(Path(sys.argv[1]), check_only=len(sys.argv) == 3)
