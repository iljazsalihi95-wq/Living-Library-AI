import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/pilot_assets.dart';

Uint8List makeArchive(int count, {bool corrupt = false}) {
  final archive = Archive();
  for (var i = 1; i <= count; i++) {
    final name = 'assets/story/frame_${i.toString().padLeft(2, '0')}.jpg';
    final bytes = corrupt && i == count
        ? <int>[1, 2, 3, 4]
        : <int>[0xff, 0xd8, 1, 2, 0xff, 0xd9];
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('accepts exactly 22 correctly named JPEG frames', () {
    final frames = PilotAssets.decodeFrames(makeArchive(22));
    expect(frames.length, 22);
    expect(frames.keys.first, 'frame_01.jpg');
    expect(frames.keys.last, 'frame_22.jpg');
  });

  test('rejects incomplete storyboard', () {
    expect(() => PilotAssets.decodeFrames(makeArchive(21)), throwsFormatException);
  });

  test('rejects malformed JPEG bytes', () {
    expect(() => PilotAssets.decodeFrames(makeArchive(22, corrupt: true)), throwsFormatException);
  });
}
