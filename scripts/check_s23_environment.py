#!/usr/bin/env python3
"""Read-only preflight for a PRIVATE Samsung S23 build.

Does not read, copy, print, or upload image contents. Run locally before
build_private_s23.py; the private ZIP must remain outside the Git repository.
"""
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def tracked_frames():
    result = subprocess.run(
        ["git", "ls-files", "--", "assets/story/"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    )
    return [
        name for name in result.stdout.splitlines()
        if Path(name).name.lower().startswith("frame_")
        and Path(name).suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
    ]


def preflight():
    problems = []
    for tool in ("git", "flutter"):
        if not shutil.which(tool):
            problems.append(f"Missing required tool: {tool}")
    if shutil.which("git"):
        try:
            tracked = tracked_frames()
            if tracked:
                problems.append(
                    f"{len(tracked)} tracked frame files block private builds. "
                    "Remove ONLY placeholder frames from the Git index in your "
                    "local checkout (git rm --cached assets/story/frame_*.jpg); "
                    "never commit private replacement images."
                )
        except subprocess.CalledProcessError:
            problems.append("Could not inspect the Git index")
    if not (ROOT / "pubspec.yaml").is_file():
        problems.append("Missing Flutter pubspec.yaml")
    if problems:
        for problem in problems:
            print("BLOCKED:", problem)
        return 1
    print("Preflight OK. Supply the owner's private 22-JPEG ZIP locally.")
    return 0


if __name__ == "__main__":
    raise SystemExit(preflight())
