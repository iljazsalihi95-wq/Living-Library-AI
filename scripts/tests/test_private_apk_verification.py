"""Offline tests for the private S23 APK verifier; no personal photos used."""
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "build_private_s23.py"
spec = importlib.util.spec_from_file_location("build_private_s23", SCRIPT)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class PrivateApkVerificationTests(unittest.TestCase):
    def make_fixture(self, directory, missing=None, changed=None, arm64=True):
        root = Path(directory)
        story = root / "assets" / "story"
        story.mkdir(parents=True)
        apk = root / "private.apk"
        with zipfile.ZipFile(apk, "w") as archive:
            for index, name in enumerate(mod.EXPECTED, 1):
                payload = b"\xff\xd8" + index.to_bytes(2, "big") + b"private-test" + b"\xff\xd9"
                (story / name).write_bytes(payload)
                if name != missing:
                    archive.writestr(
                        "assets/flutter_assets/assets/story/" + name,
                        b"changed" if name == changed else payload,
                    )
            if arm64:
                archive.writestr("lib/arm64-v8a/libflutter.so", b"synthetic-runtime")
        return root, apk

    def verify(self, root, apk):
        with patch.object(mod, "ROOT", root), patch.object(mod, "APK", apk):
            return mod.verify_apk()

    def test_complete_arm64_bundle_passes(self):
        with tempfile.TemporaryDirectory() as d:
            root, apk = self.make_fixture(d)
            self.assertEqual(len(self.verify(root, apk)), 64)

    def test_missing_frame_fails(self):
        with tempfile.TemporaryDirectory() as d:
            root, apk = self.make_fixture(d, missing="frame_22.jpg")
            with self.assertRaisesRegex(RuntimeError, "missing 1 pilot images"):
                self.verify(root, apk)

    def test_changed_frame_fails(self):
        with tempfile.TemporaryDirectory() as d:
            root, apk = self.make_fixture(d, changed="frame_05.jpg")
            with self.assertRaisesRegex(RuntimeError, "differs from local source"):
                self.verify(root, apk)

    def test_missing_arm64_runtime_fails(self):
        with tempfile.TemporaryDirectory() as d:
            root, apk = self.make_fixture(d, arm64=False)
            with self.assertRaisesRegex(RuntimeError, "no arm64 Flutter runtime"):
                self.verify(root, apk)


if __name__ == "__main__":
    unittest.main()
