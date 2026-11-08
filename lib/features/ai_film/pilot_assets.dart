import 'dart:io';
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
      final file = File('${dir.path}/frame_${i.toString().padLeft(2, '0')}.jpg');
      // Count only privately imported frames. Calling frame() here would
      // silently copy bundled reference artwork and incorrectly report 22/22
      // owner originals even when no private pilot has been installed.
      if (await _isCompleteJpeg(file)) count++;
    }
    return count;
  }

  static Future<File?> frame(String assetPath) async {
    final name = assetPath.split('/').last;
    if (!RegExp(r'^frame_(0[1-9]|1[0-9]|2[0-2])\.jpg$').hasMatch(name)) return null;
    final dir = await _directory;
    final file = File('${dir.path}/$name');
    if (await _isCompleteJpeg(file)) return file;
    // Bundled references are not the owner's imported originals.
    // Never copy placeholders to private storage and inflate installedCount().
    return null;
  }

  /// Detects truncated files in persistent storage, not just JPEG headers.
  static Future<bool> _isCompleteJpeg(File file) async {
    if (!await file.exists() || await file.length() < 4) return false;
    final handle = await file.open();
    try {
      final header = await handle.read(2);
      await handle.setPosition(await handle.length() - 2);
      final footer = await handle.read(2);
      return header.length == 2 && footer.length == 2 &&
          header[0] == 0xff && header[1] == 0xd8 &&
          footer[0] == 0xff && footer[1] == 0xd9;
    } finally {
      await handle.close();
    }
  }

  /// Validates all 22 original frames before replacing the installed set.
  static Future<int> importZip({Uint8List? zipBytes}) async {
    if (zipBytes == null) {
      final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
      if (picked.isEmpty) return 0;
      final selected = picked.single;
      // Check on-disk size before reading into memory (including direct callers).
      if (selected.path != null && await File(selected.path!).length() > 80 * 1024 * 1024) {
        throw const FormatException('Arkivi ZIP është tepër i madh.');
      }
      zipBytes = await selected.readAsBytes();
    }
    final frames = decodeFrames(zipBytes);
    final dir = await _directory;
    await dir.parent.create(recursive: true);
    // Recover the last complete import if the app was interrupted after
    // moving the old frames to backup but before activating the new set.
    final recovery = Directory('${dir.path}.backup');
    if (!await dir.exists() && await recovery.exists()) {
      await recovery.rename(dir.path);
    }
    // Import into a separate directory; keep the previous complete set intact
    // until every JPEG has been written successfully.
    final stage = await Directory('${dir.parent.path}/pilot_stage_').createTemp();
    try {
      for (final entry in frames.entries) {
        await File('${stage.path}/${entry.key}').writeAsBytes(entry.value, flush: true);
      }
      final backup = Directory('${dir.path}.backup');
      if (await backup.exists()) await backup.delete(recursive: true);
      final hadPrevious = await dir.exists();
      if (hadPrevious) await dir.rename(backup.path);
      try {
        await stage.rename(dir.path);
      } catch (_) {
        // Only roll back if activation failed. Cleanup errors must never
        // delete a successfully activated 22-frame package.
        if (await dir.exists()) await dir.delete(recursive: true);
        if (hadPrevious) await backup.rename(dir.path);
        rethrow;
      }
      // Cleanup is best-effort: a failed backup deletion must not turn a
      // successful import into data loss. The next import can retry cleanup.
      if (hadPrevious) {
        try {
          await backup.delete(recursive: true);
        } on FileSystemException {
          // Keep the valid active set; the backup is harmless.
        }
      }
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
    }
    return frames.length;
  }

  /// Pure decoder: no device access; also exercised by unit tests.
  static Map<String, Uint8List> decodeFrames(Uint8List bytes) {
    // Reject oversized compressed archives before decompression on mobile.
    if (bytes.length > 80 * 1024 * 1024) {
      throw const FormatException('Arkivi ZIP është tepër i madh.');
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    var totalUncompressed = 0;
    final frames = <String, Uint8List>{};
    for (final entry in archive) {
      if (!entry.isFile) {
        throw const FormatException('Dosjet shtesë nuk lejohen në ZIP.');
      }
      // Reject extra files and unsafe ZIP paths rather than silently skipping them.
      final rawName = entry.name.replaceAll('\\', '/');
      final parts = rawName.split('/');
      if (rawName.startsWith('/') || parts.contains('..') || parts.contains('.') || parts.contains('') || (parts.length != 1 && !(parts.length == 3 && parts[0] == 'assets' && parts[1] == 'story')) || rawName.contains('\u0000')) {
        throw const FormatException('Rrugë e pasigurt në arkivin ZIP.');
      }
      final name = parts.last;
      // The owner's original 22-frame archive includes a harmless Albanian
      // README at the ZIP root. Ignore that exact file, not arbitrary extras.
      if (rawName == 'README_SHQIP.txt') {
        if (entry.size > 64 * 1024) {
          throw const FormatException('README është tepër i madh.');
        }
        continue;
      }
      if (!RegExp(r'^frame_(0[1-9]|1[0-9]|2[0-2])\.jpg$').hasMatch(name)) {
        throw FormatException('Skedar i papritur në ZIP: $name');
      }
      // Match the offline ZIP verifier's 12 MiB per-frame limit.
      if (entry.size > 12 * 1024 * 1024) throw const FormatException('Ilustrim tepër i madh (maksimumi 12 MiB).');
      totalUncompressed += entry.size;
      if (totalUncompressed > 80 * 1024 * 1024) {
        throw const FormatException('Ilustrimet në ZIP janë tepër të mëdha.');
      }
      final data = entry.readBytes();
      if (data == null) throw const FormatException('Ilustrimi nuk mund të lexohet.');
      if (data.length < 4 || data[0] != 0xff || data[1] != 0xd8 || data[data.length - 2] != 0xff || data.last != 0xd9) {
        throw const FormatException('Ilustrim JPEG e pavlefshme.');
      }
      if (frames.containsKey(name)) {
        throw FormatException('Ilustrim e përsëritur në ZIP: $name');
      }
      frames[name] = data;
    }
    if (frames.length != 22) throw FormatException('Paketa përmban ${frames.length}/22 ilustrime. Duhen të gjitha.');
    return frames;
  }
}
