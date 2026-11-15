"""Offline regression tests for the private Samsung S23 APK verifier.

No personal photos, Flutter SDK, or network access are required.
Run: python3 -m unittest discover -s scripts -p 'test_private_s23_apk.py'
"""
import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

import build_private_s23 as builder


def elf_arm64():
    header = bytearray(20)
    header[:6] = bytes.fromhex("7f454c460201")
    header[18:20] = (183).to_bytes(2, "little")
    return bytes(header)


class PrivateApkVerifierTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.apk = self.root / "app-arm64-v8a-debug.apk"
        (self.root / "assets/story").mkdir(parents=True)
        self.images = {}
        for i, name in enumerate(builder.EXPECTED, 1):
            data = b"\xff\xd8" + bytes([i]) * 128 + b"\xff\xd9"
            (self.root / "assets/story" / name).write_bytes(data)
            self.images[name] = data

    def make_apk(self, images=None, extras=None):
        with zipfile.ZipFile(self.apk, "w") as archive:
            archive.writestr("lib/arm64-v8a/libflutter.so", elf_arm64())
            for name, data in (self.images if images is None else images).items():
                archive.writestr("assets/flutter_assets/assets/story/" + name, data)
            for name, data in (extras or {}).items():
                archive.writestr(name, data)

    def verify(self):
        with patch.object(builder, "ROOT", self.root), patch.object(builder, "APK", self.apk):
            return builder.verify_apk()

    def test_valid_private_apk_matches_local_images(self):
        self.make_apk()
        self.assertEqual(self.verify(), hashlib.sha256(self.apk.read_bytes()).hexdigest())

    def test_missing_image_rejected(self):
        self.make_apk(images={k: v for k, v in self.images.items() if k != "frame_22.jpg"})
        with self.assertRaisesRegex(RuntimeError, "missing"):
            self.verify()

    def test_unexpected_private_file_rejected(self):
        self.make_apk(extras={"assets/flutter_assets/assets/story/notes.txt": b"private"})
        with self.assertRaisesRegex(RuntimeError, "unexpected"):
            self.verify()

    def test_modified_bundled_image_rejected(self):
        images = dict(self.images)
        images["frame_01.jpg"] = b"\xff\xd8" + b"tampered" + b"\xff\xd9"
        self.make_apk(images=images)
        with self.assertRaisesRegex(RuntimeError, "differs"):
            self.verify()

    def test_duplicate_zip_entry_rejected(self):
        self.make_apk()
        with zipfile.ZipFile(self.apk, "a") as archive:
            with self.assertWarns(UserWarning):
                archive.writestr(
                    "assets/flutter_assets/assets/story/frame_01.jpg",
                    self.images["frame_01.jpg"],
                )
        with self.assertRaisesRegex(RuntimeError, "duplicate ZIP entries"):
            self.verify()

    def test_missing_arm64_runtime_rejected(self):
        with zipfile.ZipFile(self.apk, "w") as archive:
            for name, data in self.images.items():
                archive.writestr("assets/flutter_assets/assets/story/" + name, data)
        with self.assertRaisesRegex(RuntimeError, "no arm64 Flutter runtime"):
            self.verify()

    def test_empty_apk_rejected(self):
        self.apk.write_bytes(b"")
        with self.assertRaisesRegex(RuntimeError, "missing or empty"):
            self.verify()

    def test_wrong_cpu_architecture_rejected(self):
        self.make_apk()
        with zipfile.ZipFile(self.apk, "r") as archive:
            entries = {name: archive.read(name) for name in archive.namelist()}
        wrong = bytearray(elf_arm64())
        wrong[18:20] = (62).to_bytes(2, "little")
        entries["lib/arm64-v8a/libflutter.so"] = bytes(wrong)
        with zipfile.ZipFile(self.apk, "w") as archive:
            for name, data in entries.items():
                archive.writestr(name, data)
        with self.assertRaisesRegex(RuntimeError, "Invalid AArch64"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
