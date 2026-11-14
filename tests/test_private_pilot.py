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


    def test_rejects_duplicate_zip_filename(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.zip"
            with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as archive:
                for i in range(1, 23):
                    archive.writestr(f"frame_{i:02d}.jpg", fake_jpeg(i))
                # A second ZIP member with the same name must not silently win.
                archive.writestr("frame_01.jpg", fake_jpeg(1))
            with self.assertRaisesRegex(ValueError, "Duplicate"):
                pilot.prepare(path, check_only=True)

    def test_rejects_oversized_frame_before_read(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "oversized.zip"
            with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as archive:
                for i in range(1, 23):
                    archive.writestr(f"frame_{i:02d}.jpg", fake_jpeg(i))
            # Modify only the in-memory ZIP metadata to exercise the size guard,
            # without allocating a 20 MiB test photograph.
            original = zipfile.ZipFile
            class OversizedZip(original):
                def infolist(self):
                    entries = super().infolist()
                    entries[0].file_size = 20 * 1024 * 1024 + 1
                    return entries
            try:
                zipfile.ZipFile = OversizedZip
                with self.assertRaisesRegex(ValueError, "oversized frame"):
                    pilot.prepare(path, check_only=True)
            finally:
                zipfile.ZipFile = original


if __name__ == "__main__":
    unittest.main()
