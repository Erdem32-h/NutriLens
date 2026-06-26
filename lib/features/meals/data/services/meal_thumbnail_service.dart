import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MealThumbnailService {
  const MealThumbnailService();

  Future<File> _fileFor(String mealId) async {
    final dir = await getApplicationDocumentsDirectory();
    final mealDir = Directory(p.join(dir.path, 'meal_thumbnails'));
    if (!await mealDir.exists()) {
      await mealDir.create(recursive: true);
    }
    return File(p.join(mealDir.path, '$mealId.jpg'));
  }

  Future<String?> saveThumbnail({
    required String mealId,
    required Uint8List imageBytes,
  }) async {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;

      final upright = img.bakeOrientation(decoded);
      final thumb = img.copyResize(
        upright,
        width: upright.width >= upright.height ? 360 : null,
        height: upright.height > upright.width ? 360 : null,
        interpolation: img.Interpolation.average,
      );

      final file = await _fileFor(mealId);
      await file.writeAsBytes(img.encodeJpg(thumb, quality: 72), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Write already-sized JPEG bytes (downloaded from cloud Storage) straight
  /// to the meal's thumbnail file. Returns the path, or null on failure.
  Future<String?> writeDownloaded({
    required String mealId,
    required Uint8List bytes,
  }) async {
    try {
      final file = await _fileFor(mealId);
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
