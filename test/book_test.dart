import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/film_models.dart';
import 'package:living_library_ai/features/ai_film/pilot_story.dart';
import 'package:living_library_ai/features/library/book.dart';

void main() {
  test('Book and reading progress model', () {
    const book = Book(id: 'sample', title: 'Libri im', language: 'sq', chapters: [Chapter(title: 'Hyrje', paragraphs: ['Teksti'])]);
    expect(book.chapters.first.paragraphs.first, 'Teksti');
    expect(const ReadingProgress(bookId: 'sample', chapterIndex: 0, paragraphIndex: 0).isValid, isTrue);
    expect(const ReadingProgress(bookId: 'sample', chapterIndex: 0, paragraphIndex: 0).isValidFor(book), isTrue);
    expect(const ReadingProgress(bookId: 'sample', chapterIndex: 1, paragraphIndex: 0).isValidFor(book), isFalse);
    expect(const ReadingProgress(bookId: 'sample', chapterIndex: 0, paragraphIndex: 1).isValidFor(book), isFalse);
    expect(const ReadingProgress(bookId: 'other', chapterIndex: 0, paragraphIndex: 0).isValidFor(book), isFalse);
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
    expect(frames, [for (var i = 1; i <= 22; i++) 'assets/story/frame_${i.toString().padLeft(2, '0')}.jpg']);
    final characterIds = livingLibraryPilot.characters.map((character) => character.id).toSet();
    expect(characterIds, hasLength(livingLibraryPilot.characters.length));
    for (final scene in livingLibraryPilot.scenes) {
      expect(scene.referenceImagePaths, isNotEmpty, reason: scene.id);
      expect(scene.characterIds.every(characterIds.contains), isTrue, reason: scene.id);
    }
  });
  test('Reading progress skips empty chapters and stops at the end', () {
    const book = Book(id: 'reading', title: 'Test', language: 'sq', chapters: [
      Chapter(title: 'First', paragraphs: ['A', 'B']),
      Chapter(title: 'Empty', paragraphs: []),
      Chapter(title: 'Last', paragraphs: ['C']),
    ]);
    const first = ReadingProgress(bookId: 'reading', chapterIndex: 0, paragraphIndex: 0);
    final second = first.nextIn(book);
    expect(second?.chapterIndex, 0);
    expect(second?.paragraphIndex, 1);
    final third = second!.nextIn(book);
    expect(third?.chapterIndex, 2);
    expect(third?.paragraphIndex, 0);
    expect(third!.nextIn(book), isNull);
    expect(const ReadingProgress(bookId: 'other', chapterIndex: 0, paragraphIndex: 0).nextIn(book), isNull);
  });

}
