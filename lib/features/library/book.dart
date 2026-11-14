class Book {
  const Book({required this.id, required this.title, required this.language, required this.chapters});
  final String id;
  final String title;
  final String language;
  final List<Chapter> chapters;
}
class Chapter {
  const Chapter({required this.title, required this.paragraphs});
  final String title;
  final List<String> paragraphs;
}
class ReadingProgress {
  const ReadingProgress({required this.bookId, required this.chapterIndex, required this.paragraphIndex});
  final String bookId;
  final int chapterIndex;
  final int paragraphIndex;
  bool get isValid => chapterIndex >= 0 && paragraphIndex >= 0;

  /// Move to the next paragraph, including the first paragraph of the next
  /// non-empty chapter. Never return a bookmark outside the book.
  ReadingProgress? nextIn(Book book) {
    if (!isValidFor(book)) return null;
    final paragraphs = book.chapters[chapterIndex].paragraphs;
    if (paragraphIndex + 1 < paragraphs.length) {
      return ReadingProgress(bookId: bookId, chapterIndex: chapterIndex, paragraphIndex: paragraphIndex + 1);
    }
    for (var nextChapter = chapterIndex + 1; nextChapter < book.chapters.length; nextChapter++) {
      if (book.chapters[nextChapter].paragraphs.isNotEmpty) {
        return ReadingProgress(bookId: bookId, chapterIndex: nextChapter, paragraphIndex: 0);
      }
    }
    return null;
  }

  /// Navigate backwards across chapters, skipping chapters without paragraphs.
  /// Returns null at the start of the book or for a stale bookmark.
  ReadingProgress? previousIn(Book book) {
    if (!isValidFor(book)) return null;
    if (paragraphIndex > 0) {
      return ReadingProgress(bookId: bookId, chapterIndex: chapterIndex, paragraphIndex: paragraphIndex - 1);
    }
    for (var previousChapter = chapterIndex - 1; previousChapter >= 0; previousChapter--) {
      final paragraphs = book.chapters[previousChapter].paragraphs;
      if (paragraphs.isNotEmpty) {
        return ReadingProgress(bookId: bookId, chapterIndex: previousChapter, paragraphIndex: paragraphs.length - 1);
      }
    }
    return null;
  }

  /// Reject stale bookmarks pointing outside the current book contents.
  bool isValidFor(Book book) {
    if (!isValid || bookId != book.id || chapterIndex >= book.chapters.length) {
      return false;
    }
    return paragraphIndex < book.chapters[chapterIndex].paragraphs.length;
  }
}
