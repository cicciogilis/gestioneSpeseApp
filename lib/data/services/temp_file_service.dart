import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TempFileService {
  static const String _prefix = 'spesapp_';

  Future<void> cleanupTempFiles({Duration maxAge = const Duration(days: 7)}) async {
    try {
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final entities = dir.listSync(recursive: false);

      for (final entity in entities) {
        if (entity is File && _isSpesAppTempFile(entity)) {
          final stat = await entity.stat();
          final age = now.difference(stat.modified);
          if (age > maxAge) {
            try {
              await entity.delete();
            } catch (e) {
              // Ignore individual file deletion errors
            }
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  bool _isSpesAppTempFile(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    return name.startsWith(_prefix) && (name.endsWith('.csv') || name.endsWith('.pdf') || name.endsWith('.jpg') || name.endsWith('.png') || name.endsWith('.jpeg'));
  }

  Future<String> getTempFilePath(String extension) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$_prefix${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore
    }
  }
}