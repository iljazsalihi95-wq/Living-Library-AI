#!/usr/bin/env python3
"""Verify a private 22-image pilot ZIP without extracting or uploading it.

Usage: python3 tools/verify_pilot_zip.py /path/to/pilot.zip
"""
import argparse
import sys
import re
import zipfile
import stat
from pathlib import PurePosixPath

EXPECTED = 22
MAX_ARCHIVE_BYTES = 80 * 1024 * 1024
MAX_IMAGE_BYTES = 12 * 1024 * 1024
MAX_TOTAL_UNCOMPRESSED_BYTES = 80 * 1024 * 1024


def verify(path):
    if path.stat().st_size > MAX_ARCHIVE_BYTES:
        raise ValueError("ZIP exceeds 80 MiB")
    with zipfile.ZipFile(path) as archive:
        images = []
        seen = set()
        total_uncompressed = 0
        for item in archive.infolist():
            name = item.filename.replace("\\", "/")
            parts = PurePosixPath(name).parts
            # Reject Unix symlinks and special entries even if named .jpg.
            mode = (item.external_attr >> 16) & 0xFFFF
            if mode and stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR):
                raise ValueError(f"Unsafe ZIP entry type: {name}")
            if item.is_dir():
                continue
            # Do not allow hidden extra payloads in a supposedly image-only archive.
            if not name.lower().endswith((".jpg", ".jpeg")):
                raise ValueError(f"Unexpected non-image file: {name}")
            if item.flag_bits & 0x1:
                raise ValueError("Encrypted ZIP entries are not supported")
            total_uncompressed += item.file_size
            if total_uncompressed > MAX_TOTAL_UNCOMPRESSED_BYTES:
                raise ValueError("Uncompressed ZIP contents exceed 80 MiB")
            if name.startswith("/") or ".." in parts or "\x00" in name:
                raise ValueError("Unsafe ZIP path")
            if name.lower().endswith((".jpg", ".jpeg")):
                basename = PurePosixPath(name).name
                if not re.fullmatch(r"frame_(0[1-9]|1[0-9]|2[0-2])\.jpg", basename):
                    raise ValueError(f"Unexpected pilot frame name: {basename}")
                if basename in seen:
                    raise ValueError(f"Duplicate pilot frame: {basename}")
                seen.add(basename)
                if item.file_size > MAX_IMAGE_BYTES:
                    raise ValueError("JPEG exceeds 12 MiB")
                images.append(item)
        if len(images) != EXPECTED:
            raise ValueError(f"Expected {EXPECTED} JPEGs; found {len(images)}")
        expected = {f"frame_{i:02d}.jpg" for i in range(1, EXPECTED + 1)}
        if seen != expected:
            raise ValueError(f"Missing pilot frames: {sorted(expected - seen)}")
        for item in images:
            with archive.open(item) as stream:
                data = stream.read(MAX_IMAGE_BYTES + 1)
            if len(data) != item.file_size or not data.startswith(b"\xff\xd8") or not data.endswith(b"\xff\xd9"):
                raise ValueError(f"Invalid or truncated JPEG: {item.filename}")
    return len(images)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("zip_file", type=__import__("pathlib").Path)
    args = parser.parse_args()
    try:
        count = verify(args.zip_file)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(f"PASS: {count} JPEG files validated locally; nothing uploaded")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
