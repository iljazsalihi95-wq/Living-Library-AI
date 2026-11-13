#!/usr/bin/env python3
"""Offline regression tests for the Samsung S23 APK integrity verifier.

Only synthetic ZIP members are used; no owner photographs or credentials.
"""
import importlib.util
import io
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("private_s23", ROOT / "scripts" / "build_private_s23.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class S23ApkIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.apk = self.root / "app-arm64-v8a-debug.apk"
        self.assets = self.root / "assets" / "story"
        self.assets.mkdir(parents=True)
        self.patches = [
            patch.object(builder, "ROOT", self.root),
            patch.object(builder, "APK", self.apk),
        ]
        for item in self.patches:
            item.start()
            self.addCleanup(item.stop)

    def make_apk(self, missing=None, corrupt=None, arm64=True):
        with zipfile.ZipFile(self.apk, "w") as archive:
            for index, name in enumerate(builder.EXPECTED):
                payload = bytes([0xFF, 0xD8]) + bytes([index + 1]) * 32 + bytes([0xFF, 0xD9])
                (self.assets / name).write_bytes(payload)
                if name != missing:
                    archive.writestr(
                        f"assets/flutter_assets/assets/story/{name}",
                        b"wrong bytes" if name == corrupt else payload,
                    )
            if arm64:
                archive.writestr("lib/arm64-v8a/libflutter.so", b"synthetic-runtime")

    def test_matching_22_images_and_arm64(self):
        self.make_apk()
        self.assertEqual(builder.verify_apk(), builder.sha256_file(self.apk))

    def test_missing_image_is_rejected(self):
        self.make_apk(missing="frame_22.jpg")
        with self.assertRaisesRegex(RuntimeError, "missing 1 pilot images"):
            builder.verify_apk()

    def test_stale_placeholder_bytes_are_rejected(self):
        self.make_apk(corrupt="frame_07.jpg")
        with self.assertRaisesRegex(RuntimeError, "differs from local source"):
            builder.verify_apk()

    def test_missing_arm64_runtime_is_rejected(self):
        self.make_apk(arm64=False)
        with self.assertRaisesRegex(RuntimeError, "no arm64 Flutter runtime"):
            builder.verify_apk()


if __name__ == "__main__":
    unittest.main()
