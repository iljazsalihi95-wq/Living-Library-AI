import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the owner's storyboard private in app-specific storage.
class PilotAssets {
  static Future<Directory> get _directory async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/living_library_pilot');
  }

  static Future<int> installedCount() async {
    final dir = await _directory;
    var count = 0;
    for (var i = 1; i <= 22; i++) {
      if (await File('${dir.path}/frame_${i.toString().padLeft(2, '0')}.jpg').exists()) count++;
    }
    return count;
  }

  static Future<File?> frame(String assetPath) async {
    final name = assetPath.split('/').last;
    if (!RegExp(r'^frame_(0[1-9]|1[0-9]|2[0-2])\.jpg$').hasMatch(name)) return null;
    final dir = await _directory;
    final file = File('${dir.path}/$name');
    return await file.exists() ? file : null;
  }

  /// Validates all 22 original frames before replacing the installed set.
  static Future<int> importZip() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (picked.isEmpty) return 0;
    final bytes = await picked.single.readAsBytes();
    final frames = decodeFrames(bytes);
    final dir = await _directory;
    await dir.create(recursive: true);
    for (final entry in frames.entries) {
      await File('${dir.path}/${entry.key}').writeAsBytes(entry.value, flush: true);
    }
    return frames.length;
  }

  /// Pure decoder: no device access; also exercised by unit tests.
  static Map<String, Uint8List> decodeFrames(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final frames = <String, Uint8List>{};
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name.split('/').last;
      if (!RegExp(r'^frame_(0[1-9]|1[0-9]|2[0-2])\.jpg$').hasMatch(name)) continue;
      if (entry.size > 20 * 1024 * 1024) throw const FormatException('Fotografi tepër e madhe.');
      final data = entry.readBytes();
      if (data == null) throw const FormatException('Fotografia nuk mund të lexohet.');
      if (data.length < 4 || data[0] != 0xff || data[1] != 0xd8 || data[data.length - 2] != 0xff || data.last != 0xd9) {
        throw const FormatException('Fotografi JPEG e pavlefshme.');
      }
      frames[name] = data;
    }
    if (frames.length != 22) throw FormatException('Paketa përmban ${frames.length}/22 fotografi. Duhen të gjitha.');
    return frames;
  }
}
