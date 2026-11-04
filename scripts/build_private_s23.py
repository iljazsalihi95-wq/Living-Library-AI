#!/usr/bin/env python3
"""Build a private arm64 APK from the owner's local ZIP; never upload frames.

Usage: python3 scripts/build_private_s23.py /absolute/path/to/frames.zip
Requires Flutter, Android SDK, and a local checkout of this repository.
"""
import hashlib
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APK = ROOT / "build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk"
EXPECTED = [f"frame_{n:02d}.jpg" for n in range(1, 23)]


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def verify_apk():
    if not APK.is_file() or APK.stat().st_size == 0:
        raise RuntimeError("Samsung S23 APK is missing or empty")
    with zipfile.ZipFile(APK) as package:
        names = set(package.namelist())
        missing = [
            f"assets/flutter_assets/assets/story/{name}"
            for name in EXPECTED
            if f"assets/flutter_assets/assets/story/{name}" not in names
        ]
        if missing:
            raise RuntimeError(f"Private APK missing {len(missing)} pilot images: {missing}")
        if "lib/arm64-v8a/libflutter.so" not in names:
            raise RuntimeError("APK has no arm64 Flutter runtime")
        if package.testzip() is not None:
            raise RuntimeError("APK ZIP integrity check failed")
    checksum = hashlib.sha256(APK.read_bytes()).hexdigest()
    print(f"VERIFIED private S23 APK: {APK}")
    print(f"SHA256: {checksum}")
    return checksum


def build(zip_path):
    if not zip_path.is_file():
        raise FileNotFoundError(zip_path)
    # Import the validated private asset preparation script.
    sys.path.insert(0, str(ROOT / "scripts"))
    from prepare_private_pilot import prepare
    assert prepare(zip_path) == 22
    run("flutter", "pub", "get")
    run("flutter", "analyze")
    run("flutter", "test")
    run("flutter", "build", "apk", "--debug", "--split-per-abi")
    return verify_apk()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 scripts/build_private_s23.py PRIVATE_FRAMES.zip")
    build(Path(sys.argv[1]).expanduser().resolve())
