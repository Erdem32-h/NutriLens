import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../features/product/domain/entities/nutriments_entity.dart';
import 'gemini_ai_service.dart' show NutritionOcrResult;

class AnthropicServiceException implements Exception {
  final String message;
  final int? statusCode;

  const AnthropicServiceException(this.message, {this.statusCode});

  @override
  String toString() =>
      'AnthropicServiceException(status=$statusCode): $message';
}

class MealAnalysisResult {
  final String foodName;
  final int portionGrams;
  final String? ingredientsText;
  final NutrimentsEntity nutriments;
  final double confidence;
  final String description;
  final String rawJson;

  const MealAnalysisResult({
    required this.foodName,
    required this.portionGrams,
    this.ingredientsText,
    required this.nutriments,
    required this.confidence,
    required this.description,
    required this.rawJson,
  });
}

/// Output of `recalculateMealNutrition`. Carries an updated nutrition
/// payload PLUS the portion size the model used when computing it — the
/// user may have written "yarım porsiyon" and we want the UI to reflect
/// the new gram amount, not just the macros.
class RecalcResult {
  final NutrimentsEntity nutriments;
  final int portionGrams;

  const RecalcResult({required this.nutriments, required this.portionGrams});
}

/// Direct Anthropic Messages API client for nutrition-table vision OCR.
///
/// This intentionally bypasses the Supabase Gemini proxy. Keep the API key in
/// `.env`; never hard-code it here because mobile binaries are inspectable.
class AnthropicAiService {
  static const model = 'claude-opus-4-7';
  static const _messagesUrl = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';
  static const _timeout = Duration(seconds: 45);
  static const _maxAttempts = 2;

  final Dio _dio;
  final String _apiKey;
  final Duration _retryDelay;

  AnthropicAiService({
    required Dio dio,
    required String apiKey,
    Duration retryDelay = const Duration(milliseconds: 550),
  }) : _dio = dio,
       _apiKey = apiKey.trim(),
       _retryDelay = retryDelay;

  Future<String?> extractIngredientsFromBase64(
    String base64Image, {
    required String languageCode,
  }) async {
    final text = await _sendVisionPrompt(
      base64Image: base64Image,
      prompt: _ingredientsPrompt(languageCode),
      maxTokens: 900,
      logLabel: 'ingredients',
    );
    return parseIngredientsResponseText(text);
  }

  Future<NutritionOcrResult?> extractNutritionFromBase64(
    String base64Image,
  ) async {
    final text = await _sendVisionPrompt(
      base64Image: base64Image,
      prompt: _nutritionPrompt,
      maxTokens: 700,
      logLabel: 'nutrition',
    );
    return parseNutritionResponseText(text);
  }

  Future<MealAnalysisResult?> analyzeMealFromBase64(String base64Image) async {
    final text = await _sendVisionPrompt(
      base64Image: base64Image,
      prompt: _mealAnalysisPrompt,
      maxTokens: 1000,
      logLabel: 'meal',
    );
    return parseMealAnalysisResponseText(text);
  }

  /// Recalculates nutrition for an updated meal. The user may rewrite the
  /// ingredients (e.g. spotting something the AI missed) AND/OR provide a
  /// portion hint such as "yarım porsiyon", "tabağın yarısı kaldı, full
  /// tabak gibi hesapla", or an explicit gram amount. Both inputs are
  /// optional and feed into the same prompt so the model can reconcile
  /// them (e.g. "double portion" + 250 g of pasta → portion=500 g).
  Future<RecalcResult?> recalculateMealNutrition({
    required String ingredientsText,
    String? portionNote,
  }) async {
    final text = await _sendTextPrompt(
      prompt: _recalcNutritionPrompt(
        ingredientsText: ingredientsText,
        portionNote: portionNote,
      ),
      maxTokens: 700,
      logLabel: 'recalc',
    );
    return parseRecalcResponseText(text);
  }

  Future<String> _sendTextPrompt({
    required String prompt,
    required int maxTokens,
    required String logLabel,
  }) async {
    if (_apiKey.isEmpty) {
      throw const AnthropicServiceException(
        'ANTHROPIC_API_KEY is not set',
        statusCode: 401,
      );
    }

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _dio
            .post<Map<String, dynamic>>(
              _messagesUrl,
              options: Options(
                sendTimeout: _timeout,
                receiveTimeout: _timeout,
                headers: {
                  'content-type': 'application/json',
                  'x-api-key': _apiKey,
                  'anthropic-version': _apiVersion,
                },
              ),
              data: {
                'model': model,
                'max_tokens': maxTokens,
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {'type': 'text', 'text': prompt},
                    ],
                  },
                ],
              },
            )
            .timeout(_timeout);

        final text = _firstTextBlock(response.data);
        if (text == null || text.trim().isEmpty) {
          throw const AnthropicServiceException(
            'Anthropic returned empty text',
          );
        }
        return text;
      } on AnthropicServiceException {
        rethrow;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final message = _anthropicErrorMessage(e);
        debugPrint(
          '[AnthropicAI] $logLabel failed: attempt=$attempt '
          'status=$status error=$message',
        );
        if (attempt < _maxAttempts && _shouldRetry(e)) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        throw AnthropicServiceException(message, statusCode: status);
      } catch (e) {
        debugPrint('[AnthropicAI] $logLabel transport error: $e');
        if (attempt < _maxAttempts) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        throw AnthropicServiceException(e.toString());
      }
    }

    throw const AnthropicServiceException('Anthropic request failed');
  }

  Future<String> _sendVisionPrompt({
    required String base64Image,
    required String prompt,
    required int maxTokens,
    required String logLabel,
  }) async {
    if (_apiKey.isEmpty) {
      throw const AnthropicServiceException(
        'ANTHROPIC_API_KEY is not set',
        statusCode: 401,
      );
    }

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _dio
            .post<Map<String, dynamic>>(
              _messagesUrl,
              options: Options(
                sendTimeout: _timeout,
                receiveTimeout: _timeout,
                headers: {
                  'content-type': 'application/json',
                  'x-api-key': _apiKey,
                  'anthropic-version': _apiVersion,
                },
              ),
              data: {
                'model': model,
                'max_tokens': maxTokens,
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {
                        'type': 'image',
                        'source': {
                          'type': 'base64',
                          'media_type': 'image/jpeg',
                          'data': base64Image,
                        },
                      },
                      {'type': 'text', 'text': prompt},
                    ],
                  },
                ],
              },
            )
            .timeout(_timeout);

        final text = _firstTextBlock(response.data);
        if (text == null || text.trim().isEmpty) {
          throw const AnthropicServiceException(
            'Anthropic returned empty text',
          );
        }
        return text;
      } on AnthropicServiceException {
        rethrow;
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final message = _anthropicErrorMessage(e);
        debugPrint(
          '[AnthropicAI] $logLabel failed: attempt=$attempt '
          'status=$status error=$message',
        );
        if (attempt < _maxAttempts && _shouldRetry(e)) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        throw AnthropicServiceException(message, statusCode: status);
      } catch (e) {
        debugPrint('[AnthropicAI] $logLabel transport error: $e');
        if (attempt < _maxAttempts) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        throw AnthropicServiceException(e.toString());
      }
    }

    throw const AnthropicServiceException('Anthropic request failed');
  }

  @visibleForTesting
  static RecalcResult? parseRecalcResponseText(String text) {
    try {
      final jsonStr = _extractJson(text);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final nutrition = _safeMap(json['nutrition']);
      // Backward-compat: older prompt returned a flat schema. Detect that
      // by checking whether energy_kcal lives at the top level.
      final flatTopLevel = json['energy_kcal'] != null && nutrition.isEmpty;
      final src = flatTopLevel ? json : nutrition;
      final nutriments = NutrimentsEntity(
        energyKcal: _number(src['energy_kcal']),
        fat: _number(src['fat']),
        saturatedFat: _number(src['saturated_fat']),
        transFat: _number(src['trans_fat']),
        carbohydrates: _number(src['carbohydrates']),
        sugars: _number(src['sugars']),
        salt: _number(src['salt']),
        fiber: _number(src['fiber']),
        proteins: _number(src['protein']),
      );
      final portion = _safeInt(json['portion_grams']);
      return RecalcResult(
        nutriments: nutriments,
        portionGrams: portion > 0 ? portion : 0,
      );
    } catch (e) {
      debugPrint('[AnthropicAI] recalc JSON parse failed: $e');
      return null;
    }
  }

  static bool _shouldRetry(DioException e) {
    final status = e.response?.statusCode;
    if (status == 408 || status == 429) return true;
    if (status != null && status >= 500) return true;
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  static String _anthropicErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
      if (error != null) return error.toString();
    }
    return e.message ?? 'Anthropic request failed';
  }

  @visibleForTesting
  static String? parseIngredientsResponseText(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return null;

    final normalized = cleaned
        .toUpperCase()
        .replaceAll('İ', 'I')
        .replaceAll('Ğ', 'G')
        .replaceAll('Ü', 'U')
        .replaceAll('Ş', 'S')
        .replaceAll('Ö', 'O')
        .replaceAll('Ç', 'C');
    if (normalized.contains('ICINDEKILER_BULUNAMADI') ||
        normalized.contains('INGREDIENTS_NOT_FOUND')) {
      return null;
    }

    return cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  @visibleForTesting
  static NutritionOcrResult? parseNutritionResponseText(String text) {
    try {
      final jsonStr = _extractJson(text);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return _nutritionResultWithDefaults(json);
    } catch (e) {
      debugPrint('[AnthropicAI] nutrition JSON parse failed: $e');
      return null;
    }
  }

  @visibleForTesting
  static MealAnalysisResult? parseMealAnalysisResponseText(String text) {
    try {
      final jsonStr = _extractJson(text);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final nutrition = _safeMap(json['nutrition']);
      final portionGrams = _safeInt(json['portion_grams']);
      final normalizedPortionGrams = _normalizeMealPortionGrams(portionGrams);
      final nutritionScale = _mealNutritionScale(portionGrams);

      return MealAnalysisResult(
        foodName: _safeString(json['food_name'], 'Bilinmeyen Öğün'),
        portionGrams: normalizedPortionGrams,
        ingredientsText: _nullableTrimmed(json['ingredients_text']),
        nutriments: NutrimentsEntity(
          energyKcal: _scaledNumber(nutrition['energy_kcal'], nutritionScale),
          fat: _scaledNumber(nutrition['fat'], nutritionScale),
          saturatedFat: _scaledNumber(
            nutrition['saturated_fat'],
            nutritionScale,
          ),
          transFat: _scaledNumber(nutrition['trans_fat'], nutritionScale),
          carbohydrates: _scaledNumber(
            nutrition['carbohydrates'],
            nutritionScale,
          ),
          sugars: _scaledNumber(nutrition['sugars'], nutritionScale),
          salt: _scaledNumber(nutrition['salt'], nutritionScale),
          fiber: _scaledNumber(nutrition['fiber'], nutritionScale),
          proteins: _scaledNumber(nutrition['protein'], nutritionScale),
        ),
        confidence: _number(json['confidence']),
        description: _safeString(json['description'], ''),
        rawJson: jsonStr,
      );
    } catch (e) {
      debugPrint('[AnthropicAI] meal JSON parse failed: $e');
      return null;
    }
  }

  static String? _firstTextBlock(Map<String, dynamic>? response) {
    final content = response?['content'];
    if (content is! List) return null;
    for (final block in content) {
      if (block is Map && block['type'] == 'text') {
        return block['text']?.toString();
      }
    }
    return null;
  }

  static String _extractJson(String text) {
    final fencePattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = fencePattern.firstMatch(text);
    if (match != null) return match.group(1)!.trim();

    final jsonPattern = RegExp(r'\{[\s\S]*\}');
    final jsonMatch = jsonPattern.firstMatch(text);
    if (jsonMatch != null) return jsonMatch.group(0)!;

    return text.trim();
  }

  static NutritionOcrResult _nutritionResultWithDefaults(
    Map<String, dynamic> json,
  ) {
    double value(String key) {
      final raw = json[key];
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw.replaceAll(',', '.')) ?? 0;
      return 0;
    }

    return NutritionOcrResult(
      energyKcal: value('energy_kcal'),
      fat: value('fat'),
      saturatedFat: value('saturated_fat'),
      transFat: value('trans_fat'),
      carbohydrates: value('carbohydrates'),
      sugars: value('sugars'),
      salt: value('salt'),
      fiber: value('fiber'),
      protein: value('protein'),
    );
  }

  static Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static String _safeString(dynamic value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _nullableTrimmed(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  static int _normalizeMealPortionGrams(int portionGrams) {
    if (portionGrams <= 0) return 100;
    if (portionGrams > 100) return 100;
    return portionGrams;
  }

  static double _mealNutritionScale(int portionGrams) {
    if (portionGrams <= 100) return 1;
    return 100 / portionGrams;
  }

  static double _scaledNumber(dynamic value, double scale) {
    final scaled = _number(value) * scale;
    return double.parse(scaled.toStringAsFixed(2));
  }
}

String _ingredientsPrompt(String languageCode) {
  final languageName = _languageName(languageCode);
  return '''
Bu görseldeki ürün etiketinden içindekiler listesini ve alerjen bilgisini oku.

Kurallar:
- Yanıt dili: $languageName.
- İçindekiler listesini hedef dile çevirerek/metinleştirerek döndür.
- Alerjen uyarıları, "alerjen içerir", "iz/eser miktarda içerebilir", "may contain" benzeri tüm alerjen bilgilerini dahil et.
- Üretici adresi, besin tablosu, saklama koşulu, pazarlama metni ve barkod bilgilerini dahil etme.
- Katkı maddesi/E-kodu varsa koru.
- Okuyamadığın kelimeleri tahmin etme; sadece görünen metinden çıkarım yap.
- İçindekiler görünmüyorsa sadece ICINDEKILER_BULUNAMADI yaz.
- Açıklama, markdown veya JSON yazma; sadece forma yazılacak metni dön.

Çıktı formatı:
İçindekiler: ...
Alerjenler: ...
''';
}

String _languageName(String languageCode) {
  switch (languageCode.toLowerCase()) {
    case 'en':
      return 'English';
    case 'de':
      return 'German';
    case 'fr':
      return 'French';
    case 'es':
      return 'Spanish';
    case 'ar':
      return 'Arabic';
    case 'tr':
    default:
      return 'Turkish';
  }
}

const String _nutritionPrompt = '''
Bu görseldeki besin değeri tablosunu oku.

Kurallar:
- Sadece 100 g / 100 ml kolonunu kullan.
- Porsiyon, adet, %BRD/%RI/%GD kolonlarını yok say.
- Enerjide kcal değerini döndür; sadece kJ varsa kcal = kJ / 4.184.
- Tuz gram olarak dönsün. Sodyum varsa tuz = sodyum * 2.5.
- Bulamadığın her alanı 0 dön.
- Tablo yoksa tüm alanları 0 olan JSON dön.
- Sadece JSON dön, açıklama yazma.

Şema:
{
  "energy_kcal": number,
  "fat": number,
  "saturated_fat": number,
  "trans_fat": number,
  "carbohydrates": number,
  "sugars": number,
  "salt": number,
  "fiber": number,
  "protein": number
}
''';

String _recalcNutritionPrompt({
  required String ingredientsText,
  String? portionNote,
}) {
  final hasNote = portionNote != null && portionNote.trim().isNotEmpty;
  final noteSection = hasNote
      ? '''

Kullanıcı notu (porsiyon hakkında):
${portionNote.trim()}

Bu nota öncelik ver. "Yarım porsiyon" → tek kişilik porsiyonun yarısı.
"Tabak yarı kalmış / full tabak gibi hesapla" → orijinal tam porsiyonu kullan.
"300 g yedim" gibi açık gramaj varsa onu kullan.
Belirsizse en makul yorumu seç ve `portion_grams` alanını ona göre döndür.
'''
      : '''

Kullanıcı porsiyon notu vermedi. İçeriğe uygun makul bir tek kişilik
porsiyon belirle ve onu hem `portion_grams`'ta dön hem değerleri ona göre
hesapla.
''';

  return '''
Aşağıdaki içerik listesine göre tek kişilik bir öğünün tahmini besin
değerlerini hesapla.
$noteSection
İçerik:
$ingredientsText

Genel kurallar:
- `portion_grams` o porsiyonun toplam gramajıdır (yiyecek + içecek dahil).
- Nutrition değerleri o portion_grams için TOPLAM değerdir, 100 g için değil.
- Bulamadığın değerleri 0 döndür.
- Sadece JSON döndür, açıklama veya markdown yazma.

Şema:
{
  "portion_grams": number,
  "nutrition": {
    "energy_kcal": number,
    "fat": number,
    "saturated_fat": number,
    "trans_fat": number,
    "carbohydrates": number,
    "sugars": number,
    "salt": number,
    "fiber": number,
    "protein": number
  }
}
''';
}

const String _mealAnalysisPrompt = '''
Bu görseldeki öğünü analiz et.

Kurallar:
- Görselde görünen yiyecek/içecekleri tahmin et.
- TEK KİŞİLİK porsiyonu hesapla. Büyük tabak / tencere / paylaşımlı kap
  görsen bile tamamının tek kişi tarafından yeneceğini varsayma.
- Porsiyonu yiyecek türüne göre makul aralıkta seç:
  * Ana yemek (et, balık, tavuk vs.): 150–250 g
  * Pilav / makarna / kuru baklagil: 150–250 g
  * Çorba: 250–350 ml
  * Salata / garnitür: 80–150 g
  * Sandviç / dürüm / börek: 150–250 g
  * Tatlı / pasta: 80–150 g
  * Atıştırmalık / meze: 30–80 g
  * Belirsizse 200 g civarı tahmin et.
- Kullanıcı sonradan "Yeniden Hesapla" ile porsiyon notu yazabileceği için
  bu ilk tahminde **kesin bir 100 g sabiti dayatma**; fotoğrafta görünene
  ve yiyecek tipine bak.
- `portion_grams` seçtiğin porsiyonun toplam gramajıdır.
- `nutrition` alanındaki tüm değerler o porsiyon içindir (100 g referansı
  değildir).
- İçindekiler/tahmini bileşenleri Türkçe düz metin olarak yaz.
- Görsel belirsizse yine en iyi tahmini yap, `confidence`'i düşük ver.
- Bulamadığın besin değerlerini 0 döndür.
- Sadece JSON döndür, açıklama veya markdown yazma.

Şema:
{
  "food_name": string,
  "portion_grams": number,
  "ingredients_text": string,
  "nutrition": {
    "energy_kcal": number,
    "fat": number,
    "saturated_fat": number,
    "trans_fat": number,
    "carbohydrates": number,
    "sugars": number,
    "salt": number,
    "fiber": number,
    "protein": number
  },
  "confidence": number,
  "description": string
}
''';
