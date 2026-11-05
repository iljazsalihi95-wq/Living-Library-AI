#!/usr/bin/env python3
"""Verify a private 22-image pilot ZIP without extracting or uploading it.

Usage: python3 tools/verify_pilot_zip.py /path/to/pilot.zip
"""
import argparse
import sys
import zipfile
from pathlib import PurePosixPath

EXPECTED = 22
MAX_ARCHIVE_BYTES = 80 * 1024 * 1024
MAX_IMAGE_BYTES = 12 * 1024 * 1024


def verify(path):
    if path.stat().st_size > MAX_ARCHIVE_BYTES:
        raise ValueError("ZIP exceeds 80 MiB")
    with zipfile.ZipFile(path) as archive:
        images = []
        for item in archive.infolist():
            name = item.filename.replace("\\", "/")
            parts = PurePosixPath(name).parts
            if item.is_dir():
                continue
            if name.startswith("/") or ".." in parts or "\x00" in name:
                raise ValueError("Unsafe ZIP path")
            if name.lower().endswith((".jpg", ".jpeg")):
                if item.file_size > MAX_IMAGE_BYTES:
                    raise ValueError("JPEG exceeds 12 MiB")
                images.append(item)
        if len(images) != EXPECTED:
            raise ValueError(f"Expected {EXPECTED} JPEGs; found {len(images)}")
        if len({i.filename.casefold() for i in images}) != EXPECTED:
            raise ValueError("Duplicate JPEG filenames")
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
