import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/pilot_assets.dart';

Uint8List makeZip({int count = 22, bool corruptLast = false}) {
  final archive = Archive();
  for (var i = 1; i <= count; i++) {
    final name = 'assets/story/frame_${i.toString().padLeft(2, '0')}.jpg';
    final data = (corruptLast && i == count)
        ? <int>[0xff, 0xd8, 0x01, 0x02]
        : <int>[0xff, 0xd8, 0x01, 0xff, 0xd9];
    archive.addFile(ArchiveFile(name, data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('accepts exactly 22 ordered JPEG-named pilot frames', () {
    final frames = PilotAssets.decodeFrames(makeZip());
    expect(frames.length, 22);
    expect(frames.keys.first, 'frame_01.jpg');
    expect(frames.keys.last, 'frame_22.jpg');
  });

  test('rejects incomplete pilot image sets', () {
    expect(() => PilotAssets.decodeFrames(makeZip(count: 21)), throwsFormatException);
  });

  test('rejects truncated JPEG even when all 22 names exist', () {
    expect(() => PilotAssets.decodeFrames(makeZip(corruptLast: true)), throwsFormatException);
  });
}
