#!/usr/bin/env python3
"""Offline regression tests for private pilot ZIP validation; no real photos."""
import io
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from prepare_private_pilot import prepare

# Minimal JPEG marker envelope, sufficient for the importer's format checks.
def jpeg(n):
    return b"\xff\xd8" + bytes([n]) * 32 + b"\xff\xd9"


def archive_bytes(names=None, duplicate=False):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w", compression=zipfile.ZIP_STORED) as z:
        for n in range(1, 23):
            z.writestr(f"pilot/frame_{n:02d}.jpg", jpeg(1 if duplicate else n))
        if names:
            for name, payload in names:
                z.writestr(name, payload)
    return stream.getvalue()


class PrivatePilotValidationTests(unittest.TestCase):
    def check(self, data):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "private.zip"
            path.write_bytes(data)
            return prepare(path, check_only=True)

    def test_22_distinct_frames(self):
        self.assertEqual(self.check(archive_bytes()), 22)

    def test_duplicate_image_content_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate JPEG content"):
            self.check(archive_bytes(duplicate=True))

    def test_duplicate_filename_rejected(self):
        with self.assertRaisesRegex(ValueError, "Duplicate or oversized"):
            self.check(archive_bytes([("pilot/frame_01.jpg", jpeg(99))]))

    def test_path_traversal_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unsafe pilot archive path"):
            self.check(archive_bytes([("../frame_01.jpg", jpeg(99))]))

    def test_non_jpeg_rejected(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, "w") as z:
            for n in range(1, 23):
                z.writestr(f"frame_{n:02d}.jpg", b"not-a-jpeg" if n == 1 else jpeg(n))
        with self.assertRaisesRegex(ValueError, "Invalid JPEG"):
            self.check(data.getvalue())


if __name__ == "__main__":
    unittest.main()
