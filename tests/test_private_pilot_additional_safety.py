#!/usr/bin/env python3
"""Extra offline ZIP safety regressions; synthetic bytes only, no pilot photos."""
import io
import stat
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from prepare_private_pilot import prepare


def fake_jpeg(n):
    return b"\xff\xd8" + bytes([n]) * 32 + b"\xff\xd9"


def make_zip(change=None):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_STORED) as archive:
        for n in range(1, 23):
            name = f"frame_{n:02d}.jpg"
            if change and n == 1:
                change(archive, name)
            else:
                archive.writestr(name, fake_jpeg(n))
    return buffer.getvalue()


class PrivateZipAdditionalSafetyTests(unittest.TestCase):
    def validate(self, data):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "pilot.zip"
            path.write_bytes(data)
            return prepare(path, check_only=True)

    def test_check_only_does_not_extract_images(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "pilot.zip"
            path.write_bytes(make_zip())
            before = sorted(p.name for p in Path(folder).iterdir())
            self.assertEqual(prepare(path, check_only=True), 22)
            self.assertEqual(sorted(p.name for p in Path(folder).iterdir()), before)

    def test_symlink_frame_rejected(self):
        def symlink(archive, name):
            info = zipfile.ZipInfo(name)
            info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(info, b"target")
        with self.assertRaisesRegex(ValueError, "Symlink"):
            self.validate(make_zip(symlink))

    def test_empty_frame_rejected(self):
        with self.assertRaisesRegex(ValueError, "Empty or invalid"):
            self.validate(make_zip(lambda archive, name: archive.writestr(name, b"")))

    def test_oversized_frame_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate or oversized"):
            self.validate(make_zip(lambda archive, name: archive.writestr(name, b"x" * (20 * 1024 * 1024 + 1))))


if __name__ == "__main__":
    unittest.main()
