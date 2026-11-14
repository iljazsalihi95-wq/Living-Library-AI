"""Regression tests for the private pilot ZIP validator (no owner photographs)."""
import importlib.util
import io
import tempfile
import unittest
import zipfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "prepare_private_pilot.py"
spec = importlib.util.spec_from_file_location("private_pilot", SCRIPT)
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)

# Synthetic byte sequences, never real photographs. The validator only checks JPEG markers.
def jpeg(i):
    return b"\xff\xd8" + f"synthetic-test-{i:02d}".encode().ljust(128, b"x") + b"\xff\xd9"

def make_zip(path, overrides=None):
    entries = {f"frame_{i:02d}.jpg": jpeg(i) for i in range(1, 23)}
    if overrides:
        entries.update(overrides)
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_STORED) as z:
        for name, data in entries.items():
            z.writestr(name, data)

class PrivatePilotTests(unittest.TestCase):
    def test_check_only_accepts_22_distinct_frames(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "pilot.zip"
            make_zip(path)
            self.assertEqual(pilot.prepare(path, check_only=True), 22)
            self.assertEqual(list(Path(d).iterdir()), [path])

    def test_duplicate_content_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "pilot.zip"
            make_zip(path, {"frame_22.jpg": jpeg(1)})
            with self.assertRaisesRegex(ValueError, "duplicate JPEG content"):
                pilot.prepare(path, check_only=True)

    def test_invalid_jpeg_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "pilot.zip"
            make_zip(path, {"frame_22.jpg": b"not-a-jpeg"})
            with self.assertRaisesRegex(ValueError, "Invalid JPEG"):
                pilot.prepare(path, check_only=True)

    def test_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "pilot.zip"
            make_zip(path, {"../frame_22.jpg": jpeg(23)})
            with self.assertRaisesRegex(ValueError, "Unsafe pilot archive path"):
                pilot.prepare(path, check_only=True)

if __name__ == "__main__":
    unittest.main()
