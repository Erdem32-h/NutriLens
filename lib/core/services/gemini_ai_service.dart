import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/product/domain/entities/nutriments_entity.dart';
import 'anthropic_ai_service.dart'
    show AnthropicAiService, MealAnalysisResult, RecalcResult;

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
///
/// Every field is nullable so the UI can tell "value not recognized" apart
/// from "value is 0". That distinction matters on the edit screen — we
/// must not clobber a user's hand-typed value with a scan that failed to
/// read that particular row.
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

/// Thrown when the Gemini service itself fails (auth error, network down,
/// rate limit, edge function error). Distinguishes "AI couldn't be reached"
/// from "AI ran but returned no useful content" — callers can use this to
/// show a "service unavailable" warning to the user before falling back to
/// ML Kit / manual entry.
class GeminiServiceException implements Exception {
  final String message;
  final int? statusCode;

  const GeminiServiceException(this.message, {this.statusCode});

  @override
  String toString() => 'GeminiServiceException(status=$statusCode): $message';
}

/// Service for AI-powered food analysis via Supabase Edge Function.
class GeminiAiService {
  final SupabaseClient _client;

  const GeminiAiService(this._client);

  /// Improve OCR-extracted ingredients text using Gemini AI.
  ///
  /// Returns the cleaned text on success, `null` when Gemini ran but didn't
  /// produce usable output. Throws [GeminiServiceException] when the service
  /// itself failed (auth, network, rate limit, etc.) so the caller can warn
  /// the user before falling back.
  Future<String?> improveIngredientsOcr(String rawText) async {
    final response = await _invoke('ocr_ingredients', {'text': rawText});
    final result = response['result'] as String?;
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  /// Sentinel Gemini returns when no Turkish ingredients list is visible
  /// in the image. Kept in sync with the prompt in the edge function.
  static const _ingredientsNotFoundSentinel = 'İÇİNDEKİLER_BULUNAMADI';

  /// Extract the ingredients list directly from a product photo using
  /// Gemini vision. Much more robust than ML Kit for curved/glossy/rotated
  /// packaging where plain OCR fails.
  ///
  /// Pass the orientation-baked, downscaled image bytes (use
  /// `prepareOcrImage` from `core/utils/ocr_image_prep.dart`). Base64
  /// encoding happens here so callers don't have to think about it.
  ///
  /// Returns the verbatim Turkish ingredients text on success.
  /// Returns `null` when Gemini ran but couldn't find an ingredients list.
  /// Throws [GeminiServiceException] when the service itself failed (auth,
  /// network, rate limit) — caller should warn the user before falling back.
  Future<String?> extractIngredientsFromImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    return extractIngredientsFromBase64(base64Image);
  }

  /// Same as [extractIngredientsFromImage] but for callers that already
  /// have a base64-encoded payload (e.g. produced on a worker isolate by
  /// `prepareOcrImage`). Skipping a redundant `base64Encode` on the UI
  /// thread shaves the second hot spot that was contributing to ANR.
  Future<String?> extractIngredientsFromBase64(String base64Image) async {
    final response = await _invoke('ocr_ingredients_image', {
      'image_base64': base64Image,
    });
    final result = (response['result'] as String?)?.trim();
    if (result == null || result.isEmpty) return null;
    if (result.contains(_ingredientsNotFoundSentinel)) return null;
    return result;
  }

  /// Improve OCR-extracted nutrition table using Gemini AI.
  ///
  /// Returns structured nutrition data on success, `null` when Gemini ran
  /// but didn't produce usable output. Throws [GeminiServiceException] on
  /// service-level failures so the caller can warn the user.
  Future<NutritionOcrResult?> improveNutritionOcr(String rawText) async {
    final response = await _invoke('ocr_nutrition', {'text': rawText});
    final result = response['result'] as String?;
    if (result == null || result.trim().isEmpty) return null;

    try {
      // Parse JSON from Gemini response (may have markdown fences).
      final jsonStr = _extractJson(result);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return NutritionOcrResult.fromJson(json);
    } catch (e) {
      debugPrint('[GeminiAI] nutrition JSON parse failed: $e');
      // JSON parse failure is content-level, not service-level — return null
      // so caller falls back to regex parsing without scaring the user.
      return null;
    }
  }

  /// Extract the nutrition facts table directly from a product photo using
  /// Gemini vision. Replaces the legacy ML Kit + Gemini cleanup pipeline.
  ///
  /// Returns structured 100g-basis values on success.
  /// Returns `null` when Gemini ran but couldn't find/parse the table.
  /// Throws [GeminiServiceException] when the service itself failed (auth,
  /// network, rate limit) — caller should show a "service down" dialog.
  Future<NutritionOcrResult?> extractNutritionFromImage(
    Uint8List imageBytes,
  ) async {
    return extractNutritionFromBase64(base64Encode(imageBytes));
  }

  /// Same as [extractNutritionFromImage] but for pre-encoded payloads —
  /// see [extractIngredientsFromBase64] for rationale.
  Future<NutritionOcrResult?> extractNutritionFromBase64(
    String base64Image,
  ) async {
    final response = await _invoke('ocr_nutrition_image', {
      'image_base64': base64Image,
    });
    final result = (response['result'] as String?)?.trim();
    if (result == null || result.isEmpty) return null;

    try {
      final jsonStr = _extractJson(result);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return NutritionOcrResult.fromJson(json);
    } catch (e) {
      debugPrint('[GeminiAI] nutrition image JSON parse failed: $e');
      return null;
    }
  }

  /// Recognize food from photo and estimate nutrition.
  ///
  /// Throws [GeminiServiceException] on service failure, or a regular
  /// [Exception] when the response was malformed/empty (caller already
  /// handles errors with a retry button).
  Future<FoodRecognitionResult> recognizeFood(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    final response = await _invoke('food_recognition', {
      'image_base64': base64Image,
    });

    final result = response['result'] as String?;
    if (result == null || result.trim().isEmpty) {
      throw Exception('AI returned empty result');
    }

    final jsonStr = _extractJson(result);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return FoodRecognitionResult.fromJson(json);
  }

  /// Full meal-photo analysis via the server-side OpenRouter proxy (cheap
  /// model, key never on the client). Returns the same [MealAnalysisResult]
  /// shape as the direct-Anthropic path and reuses its parser so portion
  /// clamping/scaling stays identical across providers.
  ///
  /// Throws [GeminiServiceException] on service failure (auth/network/quota)
  /// so the caller can show a "service unavailable" / "quota" message.
  Future<MealAnalysisResult> analyzeMeal(
    String base64Image, {
    String languageCode = 'tr',
    required String deviceHash,
  }) async {
    final response = await _invoke('meal_analysis', {
      'image_base64': base64Image,
      'language_code': languageCode,
      'device_hash': deviceHash,
    }, requireAuth: false);
    final result = (response['result'] as String?)?.trim();
    if (result == null || result.isEmpty) {
      throw const GeminiServiceException('AI returned empty meal result');
    }
    final parsed = AnthropicAiService.parseMealAnalysisResponseText(result);
    if (parsed == null) {
      throw const GeminiServiceException('AI returned unparseable meal result');
    }
    return parsed;
  }

  /// Recalculate nutrition for edited ingredients and/or a portion note via
  /// the proxy. Returns `null` when the model produced nothing usable.
  Future<RecalcResult?> recalculateMeal({
    required String ingredientsText,
    String? portionNote,
    required String deviceHash,
  }) async {
    final response = await _invoke('recalc_nutrition', {
      'ingredients_text': ingredientsText,
      'device_hash': deviceHash,
      if (portionNote != null && portionNote.trim().isNotEmpty)
        'portion_note': portionNote,
    }, requireAuth: false);
    final result = (response['result'] as String?)?.trim();
    if (result == null || result.isEmpty) return null;
    return AnthropicAiService.parseRecalcResponseText(result);
  }

  /// Classify a product into one canonical category id via the proxy.
  /// Returns a trimmed lowercase id, or `null` when the service failed or
  /// returned nothing usable (caller falls back to the manual dropdown).
  Future<String?> classifyCategory({
    required String productName,
    String? ingredientsText,
  }) async {
    try {
      final response = await _invoke('classify_category', {
        'product_name': productName,
        if (ingredientsText != null && ingredientsText.trim().isNotEmpty)
          'ingredients_text': ingredientsText,
      });
      final result = (response['result'] as String?)?.trim().toLowerCase();
      if (result == null || result.isEmpty) return null;
      return result;
    } on GeminiServiceException {
      return null;
    }
  }

  /// Invoke the gemini-proxy Edge Function.
  ///
  /// Auto-recovers from a stale/expired session by refreshing the JWT once
  /// and retrying. The Supabase client schedules its own refreshes, but if
  /// the device was suspended or the network blipped at the wrong moment
  /// the access token can still be expired by the time we send the request.
  /// Without this retry the user sees a confusing "service unavailable"
  /// snackbar even though the only problem is a token rollover.
  ///
  /// Throws [GeminiServiceException] on any non-200 response or transport
  /// error so callers can distinguish service unavailability from empty
  /// content responses.
  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> payload, {
    bool requireAuth = true,
  }) async {
    // Pre-flight: authed actions (OCR/Gemini) need a session. The public
    // OpenRouter actions (meal_analysis / recalc_nutrition) pass
    // requireAuth:false so guests — who have no session — can call them with
    // the anon key; the edge function rate-limits those by device hash.
    if (requireAuth && _client.auth.currentSession == null) {
      throw const GeminiServiceException('Not signed in', statusCode: 401);
    }

    try {
      return await _invokeOnce(action, payload);
    } on GeminiServiceException catch (e) {
      // Single retry on auth failure: refresh the session and try once more.
      // Only meaningful for authed actions — guests have no session to refresh.
      if (requireAuth && e.statusCode == 401) {
        debugPrint('[GeminiAI] $action 401 — refreshing session and retrying');
        try {
          await _client.auth.refreshSession();
        } catch (refreshError) {
          debugPrint('[GeminiAI] session refresh failed: $refreshError');
          rethrow;
        }
        return await _invokeOnce(action, payload);
      }
      rethrow;
    }
  }

  /// Upper bound on how long any single Gemini action can take before we
  /// fail loudly. Flash + dynamic thinking on dense ingredient labels comes
  /// in at ~15-25 s in the wild; 75 s gives generous headroom without
  /// letting a stuck request hang the UI indefinitely the way the old
  /// Pro-on-Flash path did.
  static const _invokeTimeout = Duration(seconds: 75);

  Future<Map<String, dynamic>> _invokeOnce(
    String action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client.functions
          .invoke('gemini-proxy', body: {'action': action, 'payload': payload})
          .timeout(
            _invokeTimeout,
            onTimeout: () => throw const GeminiServiceException(
              'AI service timed out',
              statusCode: 408,
            ),
          );

      if (response.status != 200) {
        final errorMsg = response.data is Map
            ? (response.data['error'] ?? 'Unknown error').toString()
            : 'HTTP ${response.status}';
        debugPrint(
          '[GeminiAI] $action failed: status=${response.status} '
          'error=$errorMsg',
        );
        throw GeminiServiceException(errorMsg, statusCode: response.status);
      }

      return response.data as Map<String, dynamic>;
    } on GeminiServiceException {
      rethrow;
    } catch (e) {
      // Network errors, FunctionException, etc. — wrap as service failure.
      debugPrint('[GeminiAI] $action transport error: $e');
      throw GeminiServiceException(e.toString());
    }
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
