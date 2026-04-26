import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ingredients_ocr_service.dart';
import '../../../../core/services/nutrition_ocr_service.dart';
import 'product_provider.dart';

/// Provides the additive-detector service used to enrich Gemini's clean
/// ingredients text with E-code/Turkish-name matches against the local
/// Additives DB. The service no longer performs OCR itself — that is done
/// by Gemini vision (`GeminiAiService.extractIngredientsFromImage`).
final ocrServiceProvider = Provider<IngredientsOcrService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return IngredientsOcrService(db);
});

/// On-device ML Kit nutrition-table OCR.
///
/// The recognizer holds a native handle; we close it when the provider is
/// disposed so the OS resources are released when the app backgrounds long
/// enough for Riverpod to tear the graph down.
final nutritionOcrServiceProvider = Provider<NutritionOcrService>((ref) {
  final service = NutritionOcrService();
  ref.onDispose(() {
    // Fire-and-forget — Riverpod's onDispose is sync, and the native close
    // doesn't throw. `unawaited` documents intent and silences the lint.
    unawaited(service.dispose());
  });
  return service;
});
