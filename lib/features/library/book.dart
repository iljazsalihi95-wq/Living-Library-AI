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

  /// Bookmarks are value objects: identical positions compare equally when
  /// restoring saved reading progress or deduplicating reader updates.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingProgress &&
          other.bookId == bookId &&
          other.chapterIndex == chapterIndex &&
          other.paragraphIndex == paragraphIndex;

  @override
  int get hashCode => Object.hash(bookId, chapterIndex, paragraphIndex);

  /// Find the first readable paragraph even when introductory chapters are empty.
  /// Returns null for books with no paragraphs, avoiding an invalid bookmark.
  static ReadingProgress? firstIn(Book book) {
    for (var chapter = 0; chapter < book.chapters.length; chapter++) {
      if (book.chapters[chapter].paragraphs.isNotEmpty) {
        return ReadingProgress(bookId: book.id, chapterIndex: chapter, paragraphIndex: 0);
      }
    }
    return null;
  }

  /// Find the final readable paragraph, skipping empty trailing chapters.
  /// Useful for resuming a finished book without creating an invalid bookmark.
  static ReadingProgress? lastIn(Book book) {
    for (var chapter = book.chapters.length - 1; chapter >= 0; chapter--) {
      final paragraphs = book.chapters[chapter].paragraphs;
      if (paragraphs.isNotEmpty) {
        return ReadingProgress(bookId: book.id, chapterIndex: chapter, paragraphIndex: paragraphs.length - 1);
      }
    }
    return null;
  }

  /// Recover a bookmark after chapters or paragraphs have changed.
  /// Never transfer a bookmark from a different book.
  ReadingProgress? recoverIn(Book book) {
    if (bookId != book.id || !isValid) return null;
    if (isValidFor(book)) return this;
    if (book.chapters.isEmpty) return null;
    // When a chapter becomes empty after editing, resume at the next
    // readable chapter rather than unexpectedly jumping backwards.
    if (chapterIndex < book.chapters.length &&
        book.chapters[chapterIndex].paragraphs.isEmpty) {
      for (var chapter = chapterIndex + 1; chapter < book.chapters.length; chapter++) {
        if (book.chapters[chapter].paragraphs.isNotEmpty) {
          return ReadingProgress(bookId: bookId, chapterIndex: chapter, paragraphIndex: 0);
        }
      }
    }
    final lastChapter = chapterIndex < book.chapters.length
        ? chapterIndex
        : book.chapters.length - 1;
    for (var chapter = lastChapter; chapter >= 0; chapter--) {
      final paragraphs = book.chapters[chapter].paragraphs;
      if (paragraphs.isNotEmpty) {
        final index = chapter == chapterIndex && paragraphIndex < paragraphs.length
            ? paragraphIndex
            : paragraphs.length - 1;
        return ReadingProgress(bookId: bookId, chapterIndex: chapter, paragraphIndex: index);
      }
    }
    return firstIn(book);
  }

  /// Fraction of readable paragraphs reached (0.0 to 1.0), suitable for
  /// the reader progress bar. Invalid or foreign bookmarks return null.
  double? fractionIn(Book book) {
    if (!isValidFor(book)) return null;
    var total = 0;
    var reached = 0;
    for (var chapter = 0; chapter < book.chapters.length; chapter++) {
      final count = book.chapters[chapter].paragraphs.length;
      total += count;
      if (chapter < chapterIndex) reached += count;
    }
    return total == 0 ? null : (reached + paragraphIndex + 1) / total;
  }

  /// Jump to a paragraph using a normalized reader slider position.
  /// The first and last positions are reachable even with empty chapters.
  /// Invalid slider values do not create broken bookmarks.
  static ReadingProgress? atFraction(Book book, double fraction) {
    if (!fraction.isFinite || fraction < 0 || fraction > 1) return null;
    final total = book.chapters.fold<int>(0, (sum, chapter) => sum + chapter.paragraphs.length);
    if (total == 0) return null;
    final target = fraction == 0 ? 0 : ((fraction * total).ceil() - 1).clamp(0, total - 1);
    var index = target;
    for (var chapter = 0; chapter < book.chapters.length; chapter++) {
      final count = book.chapters[chapter].paragraphs.length;
      if (index < count) {
        return ReadingProgress(bookId: book.id, chapterIndex: chapter, paragraphIndex: index);
      }
      index -= count;
    }
    return null;
  }

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
