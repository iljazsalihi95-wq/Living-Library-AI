"""Offline checks for the private pilot bundling helper (synthetic frames only)."""
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "prepare_private_pilot.py"
spec = importlib.util.spec_from_file_location("private_pilot", SCRIPT)
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


class PrivatePilotTest(unittest.TestCase):
    def test_complete_archive_and_pubspec(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pubspec.yaml").write_text("flutter:\n  uses-material-design: true\n")
            archive = root / "frames.zip"
            with zipfile.ZipFile(archive, "w") as z:
                for i in range(1, 23):
                    z.writestr(f"assets/story/frame_{i:02d}.jpg", b"\xff\xd8" + str(i).encode() + b"\xff\xd9")
            with patch.object(pilot, "ROOT", root):
                self.assertEqual(pilot.prepare(archive), 22)
                self.assertEqual(len(list((root / "assets/story").glob("*.jpg"))), 22)
                self.assertIn("    - assets/story/", (root / "pubspec.yaml").read_text())

    def test_duplicate_photos_rejected_without_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pubspec.yaml").write_text("flutter:\n  uses-material-design: true\n")
            archive = root / "frames.zip"
            with zipfile.ZipFile(archive, "w") as z:
                for i in range(1, 23):
                    z.writestr(f"frame_{i:02d}.jpg", b"\xff\xd8same\xff\xd9")
            with patch.object(pilot, "ROOT", root):
                with self.assertRaisesRegex(ValueError, "duplicate JPEG content"):
                    pilot.prepare(archive)
                self.assertFalse((root / "assets").exists())

    def test_incomplete_archive_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / "frames.zip"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("frame_01.jpg", b"\xff\xd8test\xff\xd9")
            with patch.object(pilot, "ROOT", root):
                with self.assertRaises(ValueError):
                    pilot.prepare(archive)
                self.assertFalse((root / "assets").exists())


if __name__ == "__main__":
    unittest.main()
