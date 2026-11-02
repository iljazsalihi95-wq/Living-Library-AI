enum FilmLanguage { sq, de }

enum FilmSceneStatus { draft, ready, generating, complete, failed }

class CharacterReference {
  const CharacterReference({
    required this.id,
    required this.name,
    required this.visualNotes,
    this.referenceImagePaths = const [],
  });

  final String id;
  final String name;
  final String visualNotes;
  final List<String> referenceImagePaths;
}

class FilmScene {
  const FilmScene({
    required this.id,
    required this.title,
    required this.storyText,
    required this.motionInstructions,
    this.dialogue = '',
    this.narration = '',
    this.sfx = const [],
    this.characterIds = const [],
    this.referenceImagePath,
    this.generatedVideoPath,
    this.status = FilmSceneStatus.draft,
  });

  final String id;
  final String title;
  final String storyText;
  final String motionInstructions;
  final String dialogue;
  final String narration;
  final List<String> sfx;
  final List<String> characterIds;
  final String? referenceImagePath;
  final String? generatedVideoPath;
  final FilmSceneStatus status;

  FilmScene copyWith({
    String? referenceImagePath,
    String? generatedVideoPath,
    FilmSceneStatus? status,
  }) => FilmScene(
        id: id,
        title: title,
        storyText: storyText,
        motionInstructions: motionInstructions,
        dialogue: dialogue,
        narration: narration,
        sfx: sfx,
        characterIds: characterIds,
        referenceImagePath: referenceImagePath ?? this.referenceImagePath,
        generatedVideoPath: generatedVideoPath ?? this.generatedVideoPath,
        status: status ?? this.status,
      );
}

class FilmProject {
  const FilmProject({
    required this.id,
    required this.title,
    required this.language,
    required this.storyText,
    required this.scenes,
    this.characters = const [],
  });

  final String id;
  final String title;
  final FilmLanguage language;
  final String storyText;
  final List<FilmScene> scenes;
  final List<CharacterReference> characters;
}
