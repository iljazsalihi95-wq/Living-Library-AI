import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/pilot_assets.dart';

Uint8List _makeZip({int frameCount = 22, bool duplicate = false}) {
  final archive = Archive();
  // Minimal JPEG signatures are sufficient for the importer's byte checks.
  final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
  for (var i = 1; i <= frameCount; i++) {
    final name = 'frame_${i.toString().padLeft(2, '0')}.jpg';
    archive.addFile(ArchiveFile(name, jpeg.length, jpeg));
  }
  if (duplicate) {
    archive.addFile(ArchiveFile('other/frame_01.jpg', jpeg.length, jpeg));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('imports all 22 ordered illustration names from flat ZIP paths', () {
    final frames = PilotAssets.decodeFrames(_makeZip());
    expect(frames.length, 22);
    for (var i = 1; i <= 22; i++) {
      expect(frames.containsKey('frame_${i.toString().padLeft(2, '0')}.jpg'), isTrue);
    }
  });

  test('rejects incomplete illustration archives', () {
    expect(() => PilotAssets.decodeFrames(_makeZip(frameCount: 21)), throwsFormatException);
  });

  test('rejects repeated illustration names even in different folders', () {
    expect(() => PilotAssets.decodeFrames(_makeZip(duplicate: true)), throwsFormatException);
  });
}
