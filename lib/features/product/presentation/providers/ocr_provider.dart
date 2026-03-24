import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ingredients_ocr_service.dart';
import 'product_provider.dart';

final ocrServiceProvider = Provider<IngredientsOcrService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final service = IngredientsOcrService(db);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Process an image and return parsed ingredients.
final ocrResultProvider =
    FutureProvider.family<IngredientsParseResult, String>(
        (ref, imagePath) async {
  final ocrService = ref.watch(ocrServiceProvider);
  final rawText = await ocrService.extractText(imagePath);
  return ocrService.parseIngredients(rawText);
});
