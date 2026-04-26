import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MealThumbnailService {
  const MealThumbnailService();

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

      final dir = await getApplicationDocumentsDirectory();
      final mealDir = Directory(p.join(dir.path, 'meal_thumbnails'));
      if (!await mealDir.exists()) {
        await mealDir.create(recursive: true);
      }

      final file = File(p.join(mealDir.path, '$mealId.jpg'));
      await file.writeAsBytes(img.encodeJpg(thumb, quality: 72), flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
