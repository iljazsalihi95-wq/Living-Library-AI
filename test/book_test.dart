import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/library/book.dart';
void main() {
  test('Book and reading progress model', () {
    const book = Book(id: 'sample', title: 'Libri im', language: 'sq', chapters: [Chapter(title: 'Hyrje', paragraphs: ['Teksti'])]);
    expect(book.chapters.first.paragraphs.first, 'Teksti');
    expect(const ReadingProgress(bookId: 'sample', chapterIndex: 0, paragraphIndex: 0).isValid, isTrue);
  });
}
