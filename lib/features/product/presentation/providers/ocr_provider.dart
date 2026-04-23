import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ingredients_ocr_service.dart';
import 'product_provider.dart';

/// Provides the additive-detector service used to enrich Gemini's clean
/// ingredients text with E-code/Turkish-name matches against the local
/// Additives DB. The service no longer performs OCR itself — that is done
/// by Gemini vision (`GeminiAiService.extractIngredientsFromImage`).
final ocrServiceProvider = Provider<IngredientsOcrService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return IngredientsOcrService(db);
});
