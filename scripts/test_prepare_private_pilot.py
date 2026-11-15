"""Offline checks for the private pilot bundling helper (synthetic frames only)."""
import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch, Mock

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "prepare_private_pilot.py"
spec = importlib.util.spec_from_file_location("private_pilot", SCRIPT)
pilot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pilot)


def synthetic_jpeg(i: int) -> bytes:
    """Distinct, sufficiently sized synthetic bytes for packaging checks only."""
    return b"\xff\xd8" + (f"synthetic-frame-{i:02d}".encode() * 12) + b"\xff\xd9"


class PrivatePilotTest(unittest.TestCase):
    def test_complete_archive_and_pubspec(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pubspec.yaml").write_text("flutter:\n  uses-material-design: true\n")
            archive = root / "frames.zip"
            with zipfile.ZipFile(archive, "w") as z:
                for i in range(1, 23):
                    z.writestr(f"frame_{i:02d}.jpg", synthetic_jpeg(i))
            with patch.object(pilot, "ROOT", root), patch.object(pilot.subprocess, "run", return_value=Mock(stdout="")):
                self.assertEqual(pilot.prepare(archive), 22)
                self.assertEqual(len(list((root / "assets/story").glob("*.jpg"))), 22)
                self.assertIn("    - assets/story/", (root / "pubspec.yaml").read_text())

    def test_check_only_does_not_write_private_files_or_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "pubspec.yaml"
            original = "flutter:\n  uses-material-design: true\n"
            manifest.write_text(original)
            archive = root / "frames.zip"
            with zipfile.ZipFile(archive, "w") as z:
                for i in range(1, 23):
                    z.writestr(f"frame_{i:02d}.jpg", synthetic_jpeg(i))
            with patch.object(pilot, "ROOT", root):
                self.assertEqual(pilot.prepare(archive, check_only=True), 22)
            self.assertEqual(manifest.read_text(), original)
            self.assertFalse((root / "assets").exists())

    def test_duplicate_photos_rejected_without_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pubspec.yaml").write_text("flutter:\n  uses-material-design: true\n")
            archive = root / "frames.zip"
            with zipfile.ZipFile(archive, "w") as z:
                for i in range(1, 23):
                    z.writestr(f"frame_{i:02d}.jpg", synthetic_jpeg(1))
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


    def test_existing_private_frames_are_not_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "pubspec.yaml"
            original = "flutter:\\n  uses-material-design: true\\n"
            manifest.write_text(original)
            target = root / "assets" / "story"
            target.mkdir(parents=True)
            existing = b"previous-private-import"
            (target / "frame_01.jpg").write_bytes(existing)
            archive = root / "frames.zip"
            with zipfile.ZipFile(archive, "w") as z:
                for i in range(1, 23):
                    z.writestr(f"frame_{i:02d}.jpg", synthetic_jpeg(i))
            with patch.object(pilot, "ROOT", root), patch.object(
                pilot.subprocess, "run", return_value=Mock(stdout="")
            ):
                with self.assertRaisesRegex(ValueError, "existing private frames"):
                    pilot.prepare(archive)
            self.assertEqual((target / "frame_01.jpg").read_bytes(), existing)
            self.assertEqual(manifest.read_text(), original)
            self.assertEqual(len(list(target.iterdir())), 1)

    def test_git_tracked_frames_refused_before_any_write(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / "pubspec.yaml"
            original = "flutter:\\n  uses-material-design: true\\n"
            manifest.write_text(original)
            archive = root / "frames.zip"
            with zipfile.ZipFile(archive, "w") as z:
                for i in range(1, 23):
                    z.writestr(f"frame_{i:02d}.jpg", synthetic_jpeg(i))
            with patch.object(pilot, "ROOT", root), patch.object(
                pilot.subprocess, "run",
                return_value=Mock(stdout="assets/story/frame_01.jpg\n")
            ):
                with self.assertRaisesRegex(ValueError, "Git tracks pilot frames"):
                    pilot.prepare(archive)
            self.assertEqual(manifest.read_text(), original)
            self.assertFalse((root / "assets").exists())

    def test_unexpected_archive_document_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / "frames.zip"
            with zipfile.ZipFile(archive, "w") as z:
                for i in range(1, 23):
                    z.writestr(f"frame_{i:02d}.jpg", synthetic_jpeg(i))
                z.writestr("private-notes.txt", "do not bundle")
            with patch.object(pilot, "ROOT", root):
                with self.assertRaisesRegex(ValueError, "Unexpected entry"):
                    pilot.prepare(archive)
            self.assertFalse((root / "assets").exists())


if __name__ == "__main__":
    unittest.main()
