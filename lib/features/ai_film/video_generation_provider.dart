import 'film_models.dart';

class VideoGenerationResult {
  const VideoGenerationResult({
    required this.jobId,
    this.previewUrl,
    this.estimatedCredits,
  });

  final String jobId;
  final String? previewUrl;
  final double? estimatedCredits;
}

abstract interface class VideoGenerationProvider {
  String get id;
  bool get supportsImageToVideo;
  bool get supportsCharacterReference;
  bool get supportsLipSync;

  Future<VideoGenerationResult> generateScene({
    required FilmProject project,
    required FilmScene scene,
    required List<CharacterReference> characters,
  });

  Future<VideoGenerationResult> regenerateScene({
    required FilmProject project,
    required FilmScene scene,
    required List<CharacterReference> characters,
  });
}

/// Used until a server-side image-to-video provider is configured.
/// It intentionally never fakes a successful generation or falls back to a slideshow.
class UnconfiguredVideoGenerationProvider implements VideoGenerationProvider {
  const UnconfiguredVideoGenerationProvider();

  @override
  String get id => 'unconfigured';
  @override
  bool get supportsImageToVideo => false;
  @override
  bool get supportsCharacterReference => false;
  @override
  bool get supportsLipSync => false;

  Never _missing() => throw StateError(
        'AI video provider is not configured on the server. '
        'Configure server-side video generation credentials before rendering.',
      );

  @override
  Future<VideoGenerationResult> generateScene({required FilmProject project, required FilmScene scene, required List<CharacterReference> characters}) async => _missing();

  @override
  Future<VideoGenerationResult> regenerateScene({required FilmProject project, required FilmScene scene, required List<CharacterReference> characters}) async => _missing();
}
