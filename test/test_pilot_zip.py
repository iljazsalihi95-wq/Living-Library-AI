"""Offline regression tests for the private 22-frame pilot archive."""
import importlib.util
import io
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "verify_pilot_zip.py"
spec = importlib.util.spec_from_file_location("pilot_verify", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
JPEG = b"\xff\xd8" + b"pilot-test-only" + b"\xff\xd9"


def make_zip(path, count=22, overrides=None):
    with zipfile.ZipFile(path, "w") as archive:
        for i in range(1, count + 1):
            name = f"frame_{i:02d}.jpg"
            archive.writestr(name, (overrides or {}).get(name, JPEG))


class PilotZipTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / "pilot.zip"

    def test_complete_private_pilot(self):
        make_zip(self.path)
        self.assertEqual(module.verify(self.path), 22)

    def test_missing_frame(self):
        make_zip(self.path, count=21)
        with self.assertRaisesRegex(ValueError, "Expected 22"):
            module.verify(self.path)

    def test_truncated_jpeg(self):
        make_zip(self.path, overrides={"frame_12.jpg": b"\xff\xd8broken"})
        with self.assertRaisesRegex(ValueError, "Invalid or truncated JPEG"):
            module.verify(self.path)

    def test_duplicate_frame(self):
        make_zip(self.path)
        with zipfile.ZipFile(self.path, "a") as archive:
            archive.writestr("frame_01.jpg", JPEG)
        with self.assertRaisesRegex(ValueError, "Duplicate pilot frame"):
            module.verify(self.path)

    def test_wrong_name(self):
        with zipfile.ZipFile(self.path, "w") as archive:
            for i in range(1, 23):
                archive.writestr(f"scene_{i:02d}.jpg", JPEG)
        with self.assertRaisesRegex(ValueError, "Unexpected pilot frame name"):
            module.verify(self.path)

    def test_nested_frame_path_rejected(self):
        with zipfile.ZipFile(self.path, "w") as archive:
            for i in range(1, 23):
                archive.writestr(f"private/frame_{i:02d}.jpg", JPEG)
        with self.assertRaisesRegex(ValueError, "Unsafe ZIP path"):
            module.verify(self.path)

    def test_zip_traversal(self):
        with zipfile.ZipFile(self.path, "w") as archive:
            archive.writestr("../frame_01.jpg", JPEG)
        with self.assertRaisesRegex(ValueError, "Unsafe ZIP path"):
            module.verify(self.path)


if __name__ == "__main__":
    unittest.main()
