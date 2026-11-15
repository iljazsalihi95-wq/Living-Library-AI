"""Regression tests for the private 22-frame pilot archive validator.

These tests use synthetic JPEG-like bytes, never the owner's photographs.
Run: python3 -m unittest discover -s tests -p 'test_private_pilot_archive.py'
"""
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "prepare_private_pilot.py"
spec = importlib.util.spec_from_file_location("prepare_private_pilot", SCRIPT)
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


def frame_bytes(index):
    return b"\xff\xd8" + bytes([index]) * 256 + b"\xff\xd9"


class PrivatePilotArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive = Path(self.temp.name) / "private.zip"

    def write_archive(self, replace=None, extra=None):
        with zipfile.ZipFile(self.archive, "w", zipfile.ZIP_DEFLATED) as archive:
            for number in range(1, 23):
                name = f"frame_{number:02d}.jpg"
                data = frame_bytes(number)
                if replace and name in replace:
                    data = replace[name]
                archive.writestr(name, data)
            if extra:
                archive.writestr(*extra)

    def test_valid_archive_check_only_writes_nothing(self):
        self.write_archive()
        self.assertEqual(pilot.prepare(self.archive, check_only=True), 22)
        self.assertFalse((Path(self.temp.name) / "assets").exists())

    def test_rejects_duplicate_image_content(self):
        self.write_archive(replace={"frame_22.jpg": frame_bytes(1)})
        with self.assertRaisesRegex(ValueError, "duplicate JPEG content"):
            pilot.prepare(self.archive, check_only=True)

    def test_rejects_unrelated_document(self):
        self.write_archive(extra=("notes.txt", "private document"))
        with self.assertRaisesRegex(ValueError, "Unexpected entry"):
            pilot.prepare(self.archive, check_only=True)

    def test_rejects_nested_archive_path(self):
        self.write_archive(extra=("folder/frame_01.jpg", frame_bytes(1)))
        with self.assertRaises(ValueError):
            pilot.prepare(self.archive, check_only=True)

    def test_rejects_invalid_jpeg(self):
        self.write_archive(replace={"frame_04.jpg": b"not a JPEG" * 20})
        with self.assertRaisesRegex(ValueError, "Invalid JPEG"):
            pilot.prepare(self.archive, check_only=True)


if __name__ == "__main__":
    unittest.main()
