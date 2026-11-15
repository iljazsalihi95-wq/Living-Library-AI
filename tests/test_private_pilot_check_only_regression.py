"""Regression checks for the private pilot ZIP preflight; no owner's photos used."""
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "prepare_private_pilot.py"
spec = importlib.util.spec_from_file_location("private_pilot", SCRIPT)
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


def synthetic_jpeg(index):
    # Test fixture only: a JPEG signature, unique payload, and end marker.
    # This is not a real photograph and must never be bundled into an APK.
    return b"\xff\xd8" + bytes([index]) * 128 + b"\xff\xd9"


class PrivatePilotCheckOnlyTests(unittest.TestCase):
    def make_archive(self, path, count=22, duplicate_content=False):
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as z:
            for i in range(1, count + 1):
                z.writestr(
                    f"frame_{i:02d}.jpg",
                    synthetic_jpeg(1 if duplicate_content else i),
                )

    def test_valid_archive_check_only_does_not_write_assets(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp) / "pilot.zip"
            self.make_archive(archive)
            self.assertEqual(pilot.prepare(archive, check_only=True), 22)
            self.assertFalse((Path(temp) / "assets").exists())

    def test_missing_frame_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp) / "pilot.zip"
            self.make_archive(archive, count=21)
            with self.assertRaisesRegex(ValueError, "Expected 22 frames"):
                pilot.prepare(archive, check_only=True)

    def test_duplicate_image_bytes_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp) / "pilot.zip"
            self.make_archive(archive, duplicate_content=True)
            with self.assertRaisesRegex(ValueError, "duplicate JPEG content"):
                pilot.prepare(archive, check_only=True)

    def test_unexpected_document_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            archive = Path(temp) / "pilot.zip"
            self.make_archive(archive)
            with zipfile.ZipFile(archive, "a") as z:
                z.writestr("private_document.pdf", b"not allowed")
            with self.assertRaisesRegex(ValueError, "Unexpected entry"):
                pilot.prepare(archive, check_only=True)


if __name__ == "__main__":
    unittest.main()
