"""Offline regression tests for the private pilot ZIP validator.

Uses synthetic JPEG marker bytes only; never stores or uploads owner photos.
Run: python3 -m unittest discover -s scripts -p 'test_private_pilot.py'
"""
import tempfile
import unittest
import zipfile
from pathlib import Path

from prepare_private_pilot import prepare


def fake_jpeg(seed):
    return b"\xff\xd8" + bytes([seed]) * 128 + b"\xff\xd9"


class PrivatePilotZipTests(unittest.TestCase):
    def make_zip(self, folder, change=None):
        destination = Path(folder) / "private-test.zip"
        with zipfile.ZipFile(destination, "w") as archive:
            for number in range(1, 23):
                name = f"frame_{number:02d}.jpg"
                if change and number == 22:
                    name = change
                archive.writestr(name, fake_jpeg(number))
        return destination

    def test_accepts_22_distinct_frames_without_writing(self):
        with tempfile.TemporaryDirectory() as folder:
            self.assertEqual(prepare(self.make_zip(folder), check_only=True), 22)

    def test_rejects_missing_frame(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "Unexpected entry"):
                prepare(self.make_zip(folder, "missing.jpg"), check_only=True)

    def test_rejects_traversal(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, "Unsafe pilot archive path"):
                prepare(self.make_zip(folder, "../frame_22.jpg"), check_only=True)

    def test_rejects_duplicate_content(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / "duplicate.zip"
            with zipfile.ZipFile(destination, "w") as archive:
                for number in range(1, 23):
                    archive.writestr(f"frame_{number:02d}.jpg", fake_jpeg(1))
            with self.assertRaisesRegex(ValueError, "duplicate JPEG content"):
                prepare(destination, check_only=True)


if __name__ == "__main__":
    unittest.main()
