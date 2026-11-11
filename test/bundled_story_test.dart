import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_library_ai/features/ai_film/pilot_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temporary;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('bundled_story_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => temporary.path);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await temporary.delete(recursive: true);
  });
  test('fresh install opens all bundled drawings without a ZIP', () async {
    expect(await PilotAssets.installedCount(), 22);
    for (var i = 1; i <= 22; i++) {
      final name = 'frame_${i.toString().padLeft(2, '0')}.jpg';
      final frame = await PilotAssets.frame('assets/story/$name');
      expect(frame, isNotNull);
      final source = await rootBundle.load('assets/story/$name');
      expect(await frame!.readAsBytes(),
          source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes));
    }
  });
  test('existing imported replacement is preserved', () async {
    final directory = Directory('${temporary.path}/living_library_pilot');
    await directory.create();
    final replacement = [0xff, 0xd8, 1, 2, 3, 0xff, 0xd9];
    await File('${directory.path}/frame_01.jpg').writeAsBytes(replacement);
    final frame = await PilotAssets.frame('assets/story/frame_01.jpg');
    expect(await frame!.readAsBytes(), replacement);
  });
}
