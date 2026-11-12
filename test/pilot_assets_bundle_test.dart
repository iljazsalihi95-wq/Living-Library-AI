import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/pilot_story.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 22 pilot frames are bundled as readable JPEG assets', () async {
    final paths = livingLibraryPilot.scenes
        .expand((scene) => scene.referenceImagePaths)
        .toList();
    expect(paths.length, 22);
    expect(paths.toSet().length, 22);

    for (final path in paths) {
      final bytes = (await rootBundle.load(path)).buffer.asUint8List();
      expect(bytes.length, greaterThan(1024), reason: '$path is empty or too small');
      expect(bytes[0], 0xff, reason: '$path has no JPEG SOI marker');
      expect(bytes[1], 0xd8, reason: '$path has no JPEG SOI marker');
      expect(bytes[bytes.length - 2], 0xff, reason: '$path has no JPEG EOI marker');
      expect(bytes.last, 0xd9, reason: '$path has no JPEG EOI marker');
    }
  });
}
