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
}
