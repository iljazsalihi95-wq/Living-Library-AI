import 'film_models.dart';

class StoryboardBuilder {
  const StoryboardBuilder();

  /// Local fallback that segments only supplied story text. It does not invent events.
  /// The backend can later replace this with richer structured AI scene planning.
  FilmProject fromStory({
    required String title,
    required String storyText,
    FilmLanguage language = FilmLanguage.sq,
  }) {
    final clean = storyText.trim();
    if (clean.isEmpty) {
      return FilmProject(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title, language: language, storyText: clean, scenes: const []);
    }

    final paragraphs = clean
        .split(RegExp(r'\n\s*\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final chunks = paragraphs.isEmpty ? <String>[clean] : paragraphs;

    final scenes = <FilmScene>[];
    for (var i = 0; i < chunks.length; i++) {
      scenes.add(FilmScene(
        id: 'scene_${i + 1}',
        title: 'Skena ${i + 1}',
        storyText: chunks[i],
        motionInstructions: 'Përcakto lëvizjen vetëm nga veprimet që përmenden në këtë pjesë të tregimit.',
        narration: chunks[i],
        status: FilmSceneStatus.draft,
      ));
    }

    return FilmProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? 'Filmi im' : title.trim(),
      language: language,
      storyText: clean,
      scenes: scenes,
    );
  }
}
