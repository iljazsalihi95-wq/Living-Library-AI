import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/film_models.dart';
import 'package:living_library_ai/features/ai_film/pilot_story.dart';
import 'package:living_library_ai/features/library/book.dart';

void main() {
  test('Book and reading progress model', () {
    const book = Book(id: 'sample', title: 'Libri im', language: 'sq', chapters: [Chapter(title: 'Hyrje', paragraphs: ['Teksti'])]);
    expect(book.chapters.first.paragraphs.first, 'Teksti');
    expect(const ReadingProgress(bookId: 'sample', chapterIndex: 0, paragraphIndex: 0).isValid, isTrue);
  });

  test('Film scene keeps ordered approved reference frames', () {
    const scene = FilmScene(id: 'p01', title: 'Skena', storyText: 'Ngjarja', motionInstructions: 'Lëvizje', referenceImagePaths: ['frame-01.jpg', 'frame-02.jpg']);
    expect(scene.referenceImagePath, 'frame-01.jpg');
    expect(scene.referenceImagePaths, ['frame-01.jpg', 'frame-02.jpg']);
    final updated = scene.copyWith(referenceImagePaths: ['frame-03.jpg']);
    expect(updated.referenceImagePath, 'frame-03.jpg');
    expect(updated.storyText, scene.storyText);
  });

  test('Pilot maps all 22 approved storyboard frames exactly once', () {
    final frames = livingLibraryPilot.scenes.expand((scene) => scene.referenceImagePaths).toList();
    expect(livingLibraryPilot.scenes, hasLength(12));
    expect(frames, hasLength(22));
    expect(frames.toSet(), hasLength(22));
    expect(frames.first, 'assets/story/frame_01.jpg');
    expect(frames.last, 'assets/story/frame_22.jpg');
  });
}
