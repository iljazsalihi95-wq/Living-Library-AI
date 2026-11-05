import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/pilot_assets.dart';

Uint8List makeArchive(int count, {bool corrupt = false}) {
  final archive = Archive();
  for (var i = 1; i <= count; i++) {
    final name = 'frame_${i.toString().padLeft(2, '0')}.jpg';
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

  test('rejects unrecognized nested frame paths', () {
    final archive = Archive();
    final jpeg = <int>[0xff, 0xd8, 1, 2, 0xff, 0xd9];
    archive.addFile(ArchiveFile('unknown/story/frame_01.jpg', jpeg.length, jpeg));
    expect(() => PilotAssets.decodeFrames(Uint8List.fromList(ZipEncoder().encode(archive))), throwsFormatException);
  });

  test('rejects incomplete storyboard', () {
    expect(() => PilotAssets.decodeFrames(makeArchive(21)), throwsFormatException);
  });

  test('rejects duplicate frame names even with 22 unique frames', () {
    final archive = Archive();
    final bytes = <int>[0xff, 0xd8, 1, 2, 0xff, 0xd9];
    for (var i = 1; i <= 22; i++) {
      final name = 'frame_${i.toString().padLeft(2, '0')}.jpg';
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }
    archive.addFile(ArchiveFile('another/frame_01.jpg', bytes.length, bytes));
    expect(() => PilotAssets.decodeFrames(Uint8List.fromList(ZipEncoder().encode(archive))), throwsFormatException);
  });

  test('rejects malformed JPEG bytes', () {
    expect(() => PilotAssets.decodeFrames(makeArchive(22, corrupt: true)), throwsFormatException);
  });
  test('rejects unexpected files in the private frame package', () {
    final archive = Archive();
    final jpeg = <int>[0xff, 0xd8, 1, 2, 0xff, 0xd9];
    for (var i = 1; i <= 22; i++) {
      archive.addFile(ArchiveFile('frame_${i.toString().padLeft(2, '0')}.jpg', jpeg.length, jpeg));
    }
    final extra = <int>[1, 2, 3];
    archive.addFile(ArchiveFile('notes.txt', extra.length, extra));
    expect(() => PilotAssets.decodeFrames(Uint8List.fromList(ZipEncoder().encode(archive))), throwsFormatException);
  });

  test('rejects path traversal in a ZIP entry', () {
    final archive = Archive();
    final jpeg = <int>[0xff, 0xd8, 1, 2, 0xff, 0xd9];
    archive.addFile(ArchiveFile('../frame_01.jpg', jpeg.length, jpeg));
    expect(() => PilotAssets.decodeFrames(Uint8List.fromList(ZipEncoder().encode(archive))), throwsFormatException);
  });

  test('rejects a frame exceeding the 12 MiB mobile limit', () {
    final archive = Archive();
    final large = Uint8List(12 * 1024 * 1024 + 1);
    large[0] = 0xff;
    large[1] = 0xd8;
    large[large.length - 2] = 0xff;
    large[large.length - 1] = 0xd9;
    archive.addFile(ArchiveFile('frame_01.jpg', large.length, large));
    expect(() => PilotAssets.decodeFrames(Uint8List.fromList(ZipEncoder().encode(archive))), throwsFormatException);
  });

}
