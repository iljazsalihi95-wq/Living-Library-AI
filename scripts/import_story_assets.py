#!/usr/bin/env python3
"""Safely validate a private 22-frame pilot archive without publishing its images.

Usage:
    python3 scripts/import_story_assets.py /path/to/frames.zip --check-only
    python3 scripts/import_story_assets.py /path/to/frames.zip

The import delegates to prepare_private_pilot.py, which rejects unsafe ZIP
entries, duplicate images, tracked frame paths and unintended APK assets.
Do not commit the imported frames or modified pubspec.yaml.
"""
import argparse
from pathlib import Path

from prepare_private_pilot import prepare


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument(
        "--check-only", action="store_true",
        help="Validate the archive without writing any images",
    )
    args = parser.parse_args()
    count = prepare(args.archive.expanduser().resolve(), check_only=args.check_only)
    print(f"Validated {count} distinct JPEG pilot frames.")
    if not args.check_only:
        print("Private assets prepared locally; never commit them to GitHub.")


if __name__ == "__main__":
    main()
