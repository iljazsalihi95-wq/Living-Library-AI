#!/usr/bin/env python3
"""Offline proof that an APK contains the exact 22 owner-provided JPEG bytes.

Usage: python3 scripts/verify_private_pilot_apk.py PRIVATE_22.zip app-arm64-v8a-debug.apk
No image contents, paths outside the archive, or hashes are printed or uploaded.
"""
import hashlib
import re
import sys
from pathlib import Path
from zipfile import ZipFile

EXPECTED = {f'frame_{i:02d}.jpg' for i in range(1, 23)}


def verify(private_zip: Path, apk: Path) -> None:
    with ZipFile(private_zip) as source, ZipFile(apk) as package:
        images = {entry.filename: entry for entry in source.infolist()
                  if re.fullmatch(r'frame_(?:0[1-9]|1[0-9]|2[0-2])\.jpg', entry.filename)}
        if set(images) != EXPECTED or len(images) != 22:
            raise ValueError('Private ZIP must contain exactly 22 numbered root JPEG images')
        if len([e for e in source.infolist() if e.filename in EXPECTED]) != 22:
            raise ValueError('Duplicate private ZIP frame names')
        entries = set(package.namelist())
        for name in sorted(EXPECTED):
            asset = 'assets/flutter_assets/assets/story/' + name
            if asset not in entries:
                raise ValueError('APK is missing one or more private pilot frames')
            original = hashlib.sha256(source.read(images[name])).digest()
            bundled = hashlib.sha256(package.read(asset)).digest()
            if original != bundled:
                raise ValueError('APK does not contain the exact private pilot frames')
    print('PASS: all 22 private JPEG files match APK assets byte-for-byte (offline).')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Usage: verify_private_pilot_apk.py PRIVATE_22.zip APP.apk')
    verify(Path(sys.argv[1]), Path(sys.argv[2]))
