"""Regression tests for private 22-frame ZIP validation (synthetic fixtures only)."""
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "prepare_private_pilot.py"
spec = importlib.util.spec_from_file_location("private_pilot", SCRIPT)
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


def fake_jpeg(index):
    # Synthetic bytes for ZIP-validator tests, NOT replacements for owner's photos.
    return b"\xff\xd8" + bytes([index]) * 128 + b"\xff\xd9"


class PrivatePilotTests(unittest.TestCase):
    def make_zip(self, root, extra=None, replace=None):
        path = root / "frames.zip"
        with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as archive:
            for i in range(1, 23):
                name = f"frame_{i:02d}.jpg"
                archive.writestr(name, (replace or {}).get(name, fake_jpeg(i)))
            for name, data in (extra or {}).items():
                archive.writestr(name, data)
        return path

    def test_exactly_22_distinct_frames_check_only(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(pilot.prepare(self.make_zip(Path(directory)), check_only=True), 22)

    def test_rejects_unexpected_document(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.make_zip(Path(directory), extra={"notes.pdf": b"private"})
            with self.assertRaisesRegex(ValueError, "Unexpected entry"):
                pilot.prepare(path, check_only=True)

    def test_rejects_nested_frame(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.make_zip(Path(directory), extra={"subfolder/frame_01.jpg": fake_jpeg(1)})
            with self.assertRaises(ValueError):
                pilot.prepare(path, check_only=True)

    def test_rejects_duplicate_photo_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.make_zip(Path(directory), replace={"frame_22.jpg": fake_jpeg(1)})
            with self.assertRaisesRegex(ValueError, "duplicate JPEG content"):
                pilot.prepare(path, check_only=True)

    def test_rejects_truncated_jpeg(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.make_zip(Path(directory), replace={"frame_22.jpg": b"\xff\xd8broken"})
            with self.assertRaisesRegex(ValueError, "Invalid JPEG"):
                pilot.prepare(path, check_only=True)


if __name__ == "__main__":
    unittest.main()
