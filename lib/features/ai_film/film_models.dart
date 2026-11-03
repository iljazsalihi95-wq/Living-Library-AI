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
    this.referenceImagePaths = const [],
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

  /// Ordered, owner-approved storyboard frames for this scene.
  /// Keeping more than one frame lets image-to-video providers preserve the
  /// beginning/end composition instead of reducing a scene to a slideshow.
  final List<String> referenceImagePaths;

  /// Backwards-compatible primary frame used by the current scene editor.
  String? get referenceImagePath =>
      referenceImagePaths.isEmpty ? null : referenceImagePaths.first;

  final String? generatedVideoPath;
  final FilmSceneStatus status;

  FilmScene copyWith({
    List<String>? referenceImagePaths,
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
        referenceImagePaths: referenceImagePaths ?? this.referenceImagePaths,
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
