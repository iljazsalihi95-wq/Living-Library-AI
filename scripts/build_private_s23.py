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


def sha256_stream(stream):
    """Hash a readable stream without materializing a complete image in RAM."""
    digest = hashlib.sha256()
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(chunk)
    return digest.digest()


def sha256_file(path):
    """Hash large APKs in bounded memory on laptops and CI runners."""
    with path.open("rb") as stream:
        return sha256_stream(stream).hex()


def verify_apk():
    if not APK.is_file() or APK.stat().st_size == 0:
        raise RuntimeError("Samsung S23 APK is missing or empty")
    with zipfile.ZipFile(APK) as package:
        entries = package.namelist()
        if len(entries) != len(set(entries)):
            raise RuntimeError("APK contains duplicate ZIP entries")
        names = set(entries)
        missing = [
            f"assets/flutter_assets/assets/story/{name}"
            for name in EXPECTED
            if f"assets/flutter_assets/assets/story/{name}" not in names
        ]
        if missing:
            raise RuntimeError(f"Private APK missing {len(missing)} pilot images: {missing}")
        # Verify bundled bytes against the owner's locally supplied images, not
        # merely the presence of 22 filenames (which may be old placeholders).
        for name in EXPECTED:
            local = ROOT / "assets" / "story" / name
            if not local.is_file():
                raise RuntimeError(f"Missing local pilot source: {name}")
            with package.open(f"assets/flutter_assets/assets/story/{name}") as bundled_stream, local.open("rb") as local_stream:
                matches = sha256_stream(bundled_stream) == sha256_stream(local_stream)
            if not matches:
                raise RuntimeError(f"APK pilot image differs from local source: {name}")
        runtime = "lib/arm64-v8a/libflutter.so"
        if runtime not in names:
            raise RuntimeError("APK has no arm64 Flutter runtime")
        # Check binary architecture, not just its filename.
        for entry in sorted(name for name in names
                            if name.startswith("lib/arm64-v8a/") and name.endswith(".so")):
            with package.open(entry) as binary:
                header = binary.read(20)
            if (len(header) < 20 or header[:4] != bytes.fromhex("7f454c46")
                    or header[4:6] != bytes.fromhex("0201")
                    or int.from_bytes(header[18:20], "little") != 183):
                raise RuntimeError(f"Invalid AArch64 ELF library in APK: {entry}")
        bad_entry = package.testzip()
        if bad_entry is not None:
            raise RuntimeError(f"APK ZIP integrity check failed: {bad_entry}")
    checksum = sha256_file(APK)
    print(f"VERIFIED private S23 APK: {APK}")
    print(f"SHA256: {checksum}")
    return checksum


def ensure_private_frames_untracked():
    """Refuse builds from a checkout that tracks the owner's private photos."""
    tracked = subprocess.run(
        ["git", "ls-files", "--", "assets/story/"],
        cwd=ROOT, check=True, capture_output=True, text=True,
    ).stdout.splitlines()
    private = [
        path for path in tracked
        if Path(path).name.lower().startswith("frame_")
        and Path(path).suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")
    ]
    if private:
        raise RuntimeError(
            "Private pilot frames are tracked by Git; remove them from the "
            "Git index before building. No images were uploaded."
        )


def build(zip_path):
    if not zip_path.is_file():
        raise FileNotFoundError(zip_path)
    ensure_private_frames_untracked()
    # A private ZIP must never be part of the tracked Git tree. Refuse a
    # tracked archive even when it is outside the conventional assets folder.
    # Git pathspecs are repository-relative; an absolute ZIP path can bypass
    # ls-files checks on some Git versions. Resolve before testing the index.
    try:
        relative_zip = zip_path.resolve().relative_to(ROOT.resolve())
    except ValueError:
        relative_zip = None  # Archive outside the checkout cannot be tracked here.
    if relative_zip is not None:
        tracked_zip = subprocess.run(
            ["git", "ls-files", "--error-unmatch", "--", relative_zip.as_posix()],
            cwd=ROOT, capture_output=True, text=True,
        )
        if tracked_zip.returncode == 0:
            raise RuntimeError("Private pilot ZIP is tracked by Git; untrack it before building")
    # Never mistake an APK from an earlier run for the output of this build.
    if APK.exists():
        APK.unlink()
    # Import the validated private asset preparation script.
    sys.path.insert(0, str(ROOT / "scripts"))
    from prepare_private_pilot import prepare
    # Validate the complete archive before writing any private files locally.
    if prepare(zip_path, check_only=True) != 22:
        raise RuntimeError("Private pilot archive did not contain 22 valid images")
    if prepare(zip_path) != 22:
        raise RuntimeError("Private pilot import did not complete")
    run("flutter", "pub", "get")
    run("flutter", "analyze")
    run("flutter", "test")
    run("flutter", "build", "apk", "--debug", "--target-platform", "android-arm64", "--split-per-abi")
    return verify_apk()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 scripts/build_private_s23.py PRIVATE_FRAMES.zip")
    build(Path(sys.argv[1]).expanduser().resolve())
