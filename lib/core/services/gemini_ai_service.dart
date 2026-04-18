import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/product/domain/entities/nutriments_entity.dart';

/// Result of AI food recognition from a photo.
class FoodRecognitionResult {
  final String foodName;
  final int portionGrams;
  final double energyKcal;
  final double fat;
  final double saturatedFat;
  final double sugars;
  final double salt;
  final double fiber;
  final double protein;
  final double confidence;
  final String description;

  const FoodRecognitionResult({
    required this.foodName,
    required this.portionGrams,
    required this.energyKcal,
    required this.fat,
    required this.saturatedFat,
    required this.sugars,
    required this.salt,
    required this.fiber,
    required this.protein,
    required this.confidence,
    required this.description,
  });

  factory FoodRecognitionResult.fromJson(Map<String, dynamic> json) {
    return FoodRecognitionResult(
      foodName: json['food_name'] as String? ?? 'Bilinmeyen Yemek',
      portionGrams: (json['portion_grams'] as num?)?.toInt() ?? 0,
      energyKcal: (json['energy_kcal'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      saturatedFat: (json['saturated_fat'] as num?)?.toDouble() ?? 0,
      sugars: (json['sugars'] as num?)?.toDouble() ?? 0,
      salt: (json['salt'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
    );
  }

  /// Convert to NutrimentsEntity for HP Score calculation.
  NutrimentsEntity toNutriments() {
    return NutrimentsEntity(
      energyKcal: energyKcal,
      fat: fat,
      saturatedFat: saturatedFat,
      sugars: sugars,
      salt: salt,
      fiber: fiber,
      proteins: protein,
    );
  }
}

/// Result of AI-improved nutrition OCR.
class NutritionOcrResult {
  final double? energyKcal;
  final double? fat;
  final double? saturatedFat;
  final double? transFat;
  final double? carbohydrates;
  final double? sugars;
  final double? salt;
  final double? fiber;
  final double? protein;

  const NutritionOcrResult({
    this.energyKcal,
    this.fat,
    this.saturatedFat,
    this.transFat,
    this.carbohydrates,
    this.sugars,
    this.salt,
    this.fiber,
    this.protein,
  });

  factory NutritionOcrResult.fromJson(Map<String, dynamic> json) {
    return NutritionOcrResult(
      energyKcal: (json['energy_kcal'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      saturatedFat: (json['saturated_fat'] as num?)?.toDouble(),
      transFat: (json['trans_fat'] as num?)?.toDouble(),
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble(),
      sugars: (json['sugars'] as num?)?.toDouble(),
      salt: (json['salt'] as num?)?.toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
    );
  }
}

/// Service for AI-powered food analysis via Supabase Edge Function.
class GeminiAiService {
  final SupabaseClient _client;

  const GeminiAiService(this._client);

  /// Improve OCR-extracted ingredients text using Gemini AI.
  /// Returns cleaned text, or null on failure (caller should fallback).
  Future<String?> improveIngredientsOcr(String rawText) async {
    try {
      final response = await _invoke('ocr_ingredients', {'text': rawText});
      final result = response['result'] as String?;
      if (result == null || result.trim().isEmpty) return null;
      return result.trim();
    } catch (e) {
      debugPrint('[GeminiAI] improveIngredientsOcr error: $e');
      return null;
    }
  }

  /// Sentinel Gemini returns when no Turkish ingredients list is visible
  /// in the image. Kept in sync with the prompt in the edge function.
  static const _ingredientsNotFoundSentinel = 'İÇİNDEKİLER_BULUNAMADI';

  /// Extract the ingredients list directly from a product photo using
  /// Gemini vision. Much more robust than ML Kit for curved/glossy/rotated
  /// packaging where plain OCR fails.
  ///
  /// Returns the verbatim Turkish ingredients text on success.
  /// Returns `null` when Gemini couldn't find an ingredients list or the
  /// call failed — caller should present a retake/manual-entry dialog.
  Future<String?> extractIngredientsFromImage(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await _invoke(
        'ocr_ingredients_image',
        {'image_base64': base64Image},
      );
      final result = (response['result'] as String?)?.trim();
      if (result == null || result.isEmpty) return null;
      if (result.contains(_ingredientsNotFoundSentinel)) return null;
      return result;
    } catch (e) {
      debugPrint('[GeminiAI] extractIngredientsFromImage error: $e');
      return null;
    }
  }

  /// Improve OCR-extracted nutrition table using Gemini AI.
  /// Returns structured nutrition data, or null on failure.
  Future<NutritionOcrResult?> improveNutritionOcr(String rawText) async {
    try {
      final response = await _invoke('ocr_nutrition', {'text': rawText});
      final result = response['result'] as String?;
      if (result == null || result.trim().isEmpty) return null;

      // Parse JSON from Gemini response (may have markdown fences)
      final jsonStr = _extractJson(result);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return NutritionOcrResult.fromJson(json);
    } catch (e) {
      debugPrint('[GeminiAI] improveNutritionOcr error: $e');
      return null;
    }
  }

  /// Recognize food from photo and estimate nutrition.
  /// Throws on failure (caller should show error to user).
  Future<FoodRecognitionResult> recognizeFood(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final response = await _invoke(
      'food_recognition',
      {'image_base64': base64Image},
    );

    final result = response['result'] as String?;
    if (result == null || result.trim().isEmpty) {
      throw Exception('AI returned empty result');
    }

    final jsonStr = _extractJson(result);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return FoodRecognitionResult.fromJson(json);
  }

  /// Invoke the gemini-proxy Edge Function.
  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.functions.invoke(
      'gemini-proxy',
      body: {'action': action, 'payload': payload},
    );

    if (response.status != 200) {
      final errorMsg = response.data?['error'] ?? 'Unknown error';
      throw Exception('Edge Function error ($action): $errorMsg');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Extract JSON from a response that may contain markdown fences.
  String _extractJson(String text) {
    // Remove ```json ... ``` fences if present
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = fencePattern.firstMatch(text);
    if (match != null) return match.group(1)!.trim();

    // Try to find JSON object directly
    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final jsonMatch = jsonPattern.firstMatch(text);
    if (jsonMatch != null) return jsonMatch.group(0)!;

    return text.trim();
  }
}
