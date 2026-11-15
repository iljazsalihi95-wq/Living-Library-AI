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

  test('Restored reading bookmarks compare by value and remain book-specific', () {
    const saved = ReadingProgress(bookId: 'book-a', chapterIndex: 2, paragraphIndex: 3);
    const restored = ReadingProgress(bookId: 'book-a', chapterIndex: 2, paragraphIndex: 3);
    const otherBook = ReadingProgress(bookId: 'book-b', chapterIndex: 2, paragraphIndex: 3);
    expect(saved, restored);
    expect(saved.hashCode, restored.hashCode);
    expect({saved, restored}, hasLength(1));
    expect(saved, isNot(otherBook));
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
  test('First reading position skips empty introductory chapters', () {
    const book = Book(id: 'start', title: 'Book', language: 'sq', chapters: [
      Chapter(title: 'Cover', paragraphs: []),
      Chapter(title: 'Introduction', paragraphs: ['Përshëndetje']),
    ]);
    final first = ReadingProgress.firstIn(book);
    expect(first?.chapterIndex, 1);
    expect(first?.paragraphIndex, 0);
    expect(first?.isValidFor(book), isTrue);
    const empty = Book(id: 'empty', title: 'Empty', language: 'sq', chapters: [Chapter(title: 'Cover', paragraphs: [])]);
    expect(ReadingProgress.firstIn(empty), isNull);
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

  test('Previous paragraph skips empty chapters and rejects stale progress', () {
    const book = Book(id: 'reading', title: 'Test', language: 'sq', chapters: [
      Chapter(title: 'First', paragraphs: ['A', 'B']),
      Chapter(title: 'Empty', paragraphs: []),
      Chapter(title: 'Last', paragraphs: ['C']),
    ]);
    const last = ReadingProgress(bookId: 'reading', chapterIndex: 2, paragraphIndex: 0);
    final previous = last.previousIn(book);
    expect(previous?.chapterIndex, 0);
    expect(previous?.paragraphIndex, 1);
    expect(previous?.previousIn(book)?.paragraphIndex, 0);
    expect(previous?.previousIn(book)?.previousIn(book), isNull);
    expect(const ReadingProgress(bookId: 'wrong', chapterIndex: 2, paragraphIndex: 0).previousIn(book), isNull);
  });

  test('Last reading position skips empty trailing chapters', () {
    const book = Book(id: 'last', title: 'Book', language: 'sq', chapters: [
      Chapter(title: 'Cover', paragraphs: []),
      Chapter(title: 'Text', paragraphs: ['A', 'B']),
      Chapter(title: 'Appendix', paragraphs: []),
    ]);
    final last = ReadingProgress.lastIn(book);
    expect(last?.chapterIndex, 1);
    expect(last?.paragraphIndex, 1);
    expect(last?.isValidFor(book), isTrue);
    const empty = Book(id: 'empty', title: 'Empty', language: 'sq', chapters: [
      Chapter(title: 'Cover', paragraphs: []),
    ]);
    expect(ReadingProgress.lastIn(empty), isNull);
  });

  test('Recover stale bookmarks without crossing book identities', () {
    const book = Book(id: 'edited', title: 'Edited', language: 'sq', chapters: [
      Chapter(title: 'Intro', paragraphs: []),
      Chapter(title: 'Text', paragraphs: ['A', 'B']),
      Chapter(title: 'Removed', paragraphs: []),
    ]);
    const stale = ReadingProgress(bookId: 'edited', chapterIndex: 5, paragraphIndex: 9);
    final recovered = stale.recoverIn(book);
    expect(recovered?.chapterIndex, 1);
    expect(recovered?.paragraphIndex, 1);
    expect(recovered?.isValidFor(book), isTrue);
    expect(const ReadingProgress(bookId: 'other', chapterIndex: 5, paragraphIndex: 9).recoverIn(book), isNull);
    expect(const ReadingProgress(bookId: 'edited', chapterIndex: -1, paragraphIndex: 0).recoverIn(book), isNull);
    expect(const ReadingProgress(bookId: 'edited', chapterIndex: 0, paragraphIndex: 0).recoverIn(book)?.chapterIndex, 1);
  });

  test('Reading progress fraction counts paragraphs, not empty chapters', () {
    const book = Book(id: 'fraction', title: 'Book', language: 'sq', chapters: [
      Chapter(title: 'Cover', paragraphs: []),
      Chapter(title: 'Part one', paragraphs: ['A', 'B']),
      Chapter(title: 'Empty', paragraphs: []),
      Chapter(title: 'Part two', paragraphs: ['C', 'D']),
    ]);
    expect(const ReadingProgress(bookId: 'fraction', chapterIndex: 1, paragraphIndex: 0).fractionIn(book), 0.25);
    expect(const ReadingProgress(bookId: 'fraction', chapterIndex: 3, paragraphIndex: 0).fractionIn(book), 0.75);
    expect(const ReadingProgress(bookId: 'fraction', chapterIndex: 3, paragraphIndex: 1).fractionIn(book), 1.0);
    expect(const ReadingProgress(bookId: 'other', chapterIndex: 3, paragraphIndex: 1).fractionIn(book), isNull);
  });

  test('Reader slider jumps across empty chapters and validates fractions', () {
    const book = Book(id: 'seek', title: 'Book', language: 'sq', chapters: [
      Chapter(title: 'Cover', paragraphs: []),
      Chapter(title: 'One', paragraphs: ['A', 'B']),
      Chapter(title: 'Blank', paragraphs: []),
      Chapter(title: 'Two', paragraphs: ['C', 'D']),
    ]);
    expect(ReadingProgress.atFraction(book, 0)?.chapterIndex, 1);
    expect(ReadingProgress.atFraction(book, 0.25)?.paragraphIndex, 0);
    expect(ReadingProgress.atFraction(book, 0.75)?.chapterIndex, 3);
    expect(ReadingProgress.atFraction(book, 1)?.paragraphIndex, 1);
    expect(ReadingProgress.atFraction(book, -0.1), isNull);
    expect(ReadingProgress.atFraction(book, double.nan), isNull);
    expect(ReadingProgress.atFraction(book, double.infinity), isNull);
    const empty = Book(id: 'empty', title: 'Empty', language: 'sq', chapters: []);
    expect(ReadingProgress.atFraction(empty, 0.5), isNull);
  });

}
