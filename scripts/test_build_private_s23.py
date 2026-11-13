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
        self.original_root = module.ROOT
        module.ROOT = Path(self.tmp.name)
        module.APK = module.ROOT / "pilot.apk"
        source = module.ROOT / "assets" / "story"
        source.mkdir(parents=True)
        for name in module.EXPECTED:
            (source / name).write_bytes(b"\xff\xd8synthetic\xff\xd9")

    def tearDown(self):
        module.APK = self.original_apk
        module.ROOT = self.original_root
        self.tmp.cleanup()

    def make_apk(self, frames=22, arm64=True, changed_frame=None):
        with zipfile.ZipFile(module.APK, "w") as archive:
            for number in range(1, frames + 1):
                archive.writestr(
                    f"assets/flutter_assets/assets/story/frame_{number:02d}.jpg",
                    b"\xff\xd8changed\xff\xd9" if number == changed_frame else b"\xff\xd8synthetic\xff\xd9",
                )
            if arm64:
                archive.writestr("lib/arm64-v8a/libflutter.so", b"\x7fELF\x02\x01\x01" + b"\x00" * 11 + b"\x03\x00\xb7\x00" + b"\x00" * 40)

    def test_valid_package_passes(self):
        self.make_apk()
        self.assertEqual(len(module.verify_apk()), 64)

    def test_missing_photo_fails(self):
        self.make_apk(frames=21)
        with self.assertRaisesRegex(RuntimeError, "missing 1 pilot images"):
            module.verify_apk()

    def test_changed_photo_fails(self):
        self.make_apk(changed_frame=1)
        with self.assertRaisesRegex(RuntimeError, "differs from local source: frame_01.jpg"):
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
