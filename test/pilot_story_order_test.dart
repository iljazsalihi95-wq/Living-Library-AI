import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/pilot_story.dart';

void main() {
  test('pilot uses all 22 owner frames exactly once and in order', () {
    final frames = livingLibraryPilot.scenes
        .expand((scene) => scene.referenceImagePaths)
        .toList();
    expect(livingLibraryPilot.scenes.length, 12);
    expect(frames.length, 22);
    expect(frames.toSet().length, 22);
    expect(frames, [
      for (var i = 1; i <= 22; i++)
        'assets/story/frame_${i.toString().padLeft(2, '0')}.jpg',
    ]);
  });

  test('every scene has an event, motion notes and original references', () {
    for (final scene in livingLibraryPilot.scenes) {
      expect(scene.storyText.trim(), isNotEmpty);
      expect(scene.motionInstructions.trim(), isNotEmpty);
      expect(scene.referenceImagePaths, isNotEmpty);
    }
  });
}
