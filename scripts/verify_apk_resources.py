"""Verify actual APK pixels, ABI and optional approved illustrations."""
from pathlib import Path
import io
import hashlib
import json
import zipfile
from PIL import Image, ImageChops

apk = Path('build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk')
with zipfile.ZipFile(apk) as archive:
    names = archive.namelist()
    assert len(names) == len(set(names)), 'Duplicate APK entries are not allowed'
    assert 'lib/arm64-v8a/libflutter.so' in names, 'ARM64 Flutter runtime missing'
    assert not any(name.startswith(('lib/x86', 'lib/armeabi')) for name in names), 'Unexpected non-ARM64 runtime'
    icons = [name for name in names if name.startswith('res/') and name.endswith('/ic_launcher.png')]
    assert len(icons) >= 5, f'Expected all five launcher densities, found {len(icons)}'
    expected = {}
    for path in Path('android/app/src/main/res').glob('mipmap-*/ic_launcher.png'):
        with Image.open(path) as image:
            expected[image.size] = image.convert('RGBA').copy()
    found = set()
    for name in icons:
        with Image.open(io.BytesIO(archive.read(name))) as image:
            actual = image.convert('RGBA')
            assert actual.size in expected, f'Unexpected launcher size: {name}'
            assert ImageChops.difference(actual, expected[actual.size]).getbbox() is None, f'Launcher pixels differ: {name}'
            found.add(actual.size)
    assert found == set(expected), 'APK launcher densities do not match generated artwork'
    frames = sorted(Path('assets/story').glob('frame_*.jpg'))
    expected_names = [f'frame_{number:02d}.jpg' for number in range(1, 23)]
    assert [frame.name for frame in frames] == expected_names, 'Expected exactly 22 numbered pilot illustrations'
    for frame in frames:
        with Image.open(frame) as illustration:
            illustration.verify()
        with Image.open(frame) as illustration:
            assert illustration.format == 'JPEG', f'Not a JPEG: {frame.name}'
            assert illustration.width >= 64 and illustration.height >= 64, f'Illustration too small: {frame.name}'
            illustration.load()  # Decode every pixel; JPEG header checks alone miss truncated image data
    bundled_frames = sorted(name for name in names if name.startswith('assets/flutter_assets/assets/story/'))
    expected_frames = sorted('assets/flutter_assets/' + frame.as_posix() for frame in frames)
    assert bundled_frames == expected_frames, 'APK contains missing or unexpected story assets'
    for frame in frames:
        name = 'assets/flutter_assets/' + frame.as_posix()
        assert archive.read(name) == frame.read_bytes(), f'Illustration missing/changed: {frame.name}'
    manifest = {'provenance_verified': False, 'note': 'Hashes prove packaged bytes, not that artwork matches the owner-approved originals.', 'frames': [{'name': frame.name, 'sha256': hashlib.sha256(frame.read_bytes()).hexdigest()} for frame in frames]}
    output = apk.with_suffix('.frames.json')
    output.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'APK verified: ARM64, {len(found)} matching launcher sizes, {len(frames)} bundled JPEG illustrations (provenance not verified); SHA-256 manifest: {output}')
