import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/pilot_story.dart';

void main() {
  test('pilot storyboard references exactly 22 ordered unique frames', () {
    final paths = livingLibraryPilot.scenes
        .expand((scene) => scene.referenceImagePaths)
        .toList();
    final expected = List.generate(
      22,
      (index) => 'assets/story/frame_${(index + 1).toString().padLeft(2, '0')}.jpg',
    );
    expect(paths, expected);
    expect(paths.toSet().length, 22);
    expect(livingLibraryPilot.scenes, isNotEmpty);
  });
}
