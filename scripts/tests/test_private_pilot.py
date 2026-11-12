"""Offline safety tests for private pilot imports; synthetic JPEG markers only.

Run: python3 -m unittest discover -s scripts/tests -v
No owner's photographs are included or uploaded.
"""
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "prepare_private_pilot.py"
spec = importlib.util.spec_from_file_location("prepare_private_pilot", MODULE)
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


def fake_jpeg(n):
    return b"\xff\xd8" + n.to_bytes(4, "big") + b"synthetic-test-only" + b"\xff\xd9"


class PrivatePilotValidationTests(unittest.TestCase):
    def make_archive(self, directory, replacement=None):
        path = Path(directory) / "pilot.zip"
        entries = {f"frame_{n:02d}.jpg": fake_jpeg(n) for n in range(1, 23)}
        if replacement:
            entries.update(replacement)
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as z:
            for name, data in entries.items():
                z.writestr(name, data)
        return path

    def test_22_distinct_frames_check_only(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertEqual(pilot.prepare(self.make_archive(d), check_only=True), 22)

    def test_duplicate_content_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.make_archive(d, {"frame_22.jpg": fake_jpeg(1)})
            with self.assertRaisesRegex(ValueError, "duplicate JPEG content"):
                pilot.prepare(path, check_only=True)

    def test_invalid_jpeg_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.make_archive(d, {"frame_07.jpg": b"not-a-jpeg"})
            with self.assertRaisesRegex(ValueError, "Invalid JPEG"):
                pilot.prepare(path, check_only=True)

    def test_archive_traversal_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = self.make_archive(d, {"../frame_07.jpg": fake_jpeg(99)})
            with self.assertRaisesRegex(ValueError, "Unsafe pilot archive path"):
                pilot.prepare(path, check_only=True)

    def test_missing_frame_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "missing.zip"
            with zipfile.ZipFile(path, "w") as z:
                for n in range(1, 22):
                    z.writestr(f"frame_{n:02d}.jpg", fake_jpeg(n))
            with self.assertRaisesRegex(ValueError, "Expected 22 frames"):
                pilot.prepare(path, check_only=True)


if __name__ == "__main__":
    unittest.main()
