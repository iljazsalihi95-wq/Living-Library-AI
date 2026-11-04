"""Tests APK inspection without publishing private pilot photographs."""
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).with_name("build_private_s23.py")
spec = importlib.util.spec_from_file_location("private_s23", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PrivateApkVerificationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.original_apk = module.APK
        module.APK = Path(self.tmp.name) / "pilot.apk"

    def tearDown(self):
        module.APK = self.original_apk
        self.tmp.cleanup()

    def make_apk(self, frames=22, arm64=True):
        with zipfile.ZipFile(module.APK, "w") as archive:
            for number in range(1, frames + 1):
                archive.writestr(
                    f"assets/flutter_assets/assets/story/frame_{number:02d}.jpg",
                    b"\xff\xd8synthetic\xff\xd9",
                )
            if arm64:
                archive.writestr("lib/arm64-v8a/libflutter.so", b"synthetic")

    def test_valid_package_passes(self):
        self.make_apk()
        self.assertEqual(len(module.verify_apk()), 64)

    def test_missing_photo_fails(self):
        self.make_apk(frames=21)
        with self.assertRaisesRegex(RuntimeError, "missing 1 pilot images"):
            module.verify_apk()

    def test_missing_arm64_runtime_fails(self):
        self.make_apk(arm64=False)
        with self.assertRaisesRegex(RuntimeError, "arm64"):
            module.verify_apk()

    def test_missing_apk_fails(self):
        with self.assertRaisesRegex(RuntimeError, "missing or empty"):
            module.verify_apk()


if __name__ == "__main__":
    unittest.main()
