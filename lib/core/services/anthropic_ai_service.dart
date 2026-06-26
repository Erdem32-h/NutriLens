import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../features/product/domain/entities/nutriments_entity.dart';
import 'gemini_ai_service.dart' show NutritionOcrResult;

class AnthropicServiceException implements Exception {
  final String message;
  final int? statusCode;

  /// True when the failure is caused by the Anthropic account running out of
  /// credit / hitting a quota or rate limit (HTTP 429, or a 400 billing
  /// error). Lets the UI show a "quota exhausted" message instead of a
  /// generic outage, and makes the real cause obvious in crash reports.
  final bool isQuota;

  const AnthropicServiceException(
    this.message, {
    this.statusCode,
    this.isQuota = false,
  });

  @override
  String toString() =>
      'AnthropicServiceException(status=$statusCode, quota=$isQuota): $message';
}

/// Classifies an Anthropic error as a billing/quota/rate-limit condition.
bool _isQuotaError(int? status, String message) {
  if (status == 429) return true;
  final m = message.toLowerCase();
  return m.contains('credit balance') ||
      m.contains('too low') ||
      m.contains('quota') ||
      m.contains('billing') ||
      m.contains('insufficient');
}

class MealAnalysisResult {
  final String foodName;
  final int portionGrams;
  final String? ingredientsText;
  final NutrimentsEntity nutriments;
  final double confidence;
  final String description;
  final String rawJson;

  /// True when the photo is a packaged/branded retail product (box, bag,
  /// bottle) rather than a prepared dish. The meal estimator is wrong for
  /// these — the UI steers the user to barcode scanning instead.
  final bool isPackagedProduct;

  const MealAnalysisResult({
    required this.foodName,
    required this.portionGrams,
    this.ingredientsText,
    required this.nutriments,
    required this.confidence,
    required this.description,
    required this.rawJson,
    this.isPackagedProduct = false,
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
  /// Default Messages API model. Vision meal-analysis is a structured
  /// extraction task (image → JSON), not deep reasoning, so Sonnet is the
  /// right cost/quality point and is vision-capable. Overridable at runtime
  /// via the `ANTHROPIC_MODEL` env var so a future model retirement is an
  /// ops change, not an app release (the previous hardcoded
  /// `claude-opus-4-7` was retired and 404'd, taking the whole AI flow down).
  static const _defaultModel = 'claude-sonnet-4-0';
  static const _messagesUrl = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';
  static const _timeout = Duration(seconds: 45);
  static const _maxAttempts = 2;

  final Dio _dio;
  final String _apiKey;
  final String model;
  final Duration _retryDelay;

  AnthropicAiService({
    required Dio dio,
    required String apiKey,
    String? model,
    Duration retryDelay = const Duration(milliseconds: 550),
  }) : _dio = dio,
       _apiKey = apiKey.trim(),
       model = (model == null || model.trim().isEmpty)
           ? _defaultModel
           : model.trim(),
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

  Future<MealAnalysisResult?> analyzeMealFromBase64(
    String base64Image, {
    String languageCode = 'tr',
  }) async {
    final text = await _sendVisionPrompt(
      base64Image: base64Image,
      prompt: _mealAnalysisPrompt(languageCode),
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
        throw AnthropicServiceException(message, statusCode: status, isQuota: _isQuotaError(status, message));
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
        throw AnthropicServiceException(message, statusCode: status, isQuota: _isQuotaError(status, message));
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

  /// Public: also used by the proxy-backed meal flow to parse OpenRouter
  /// output, so it reuses the same portion-clamping logic.
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

  /// Public: also used by the proxy-backed meal flow to parse OpenRouter
  /// output, so it reuses the same portion-clamping + scaling logic.
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
        confidence: _normalizeConfidence(json['confidence']),
        description: _safeString(json['description'], ''),
        rawJson: jsonStr,
        isPackagedProduct: _safeBool(json['is_packaged_product']),
      );
    } catch (e) {
      debugPrint('[AnthropicAI] meal JSON parse failed: $e');
      return null;
    }
  }

  /// Tolerant boolean parse — models return real bools, "true"/"false"
  /// strings, or 1/0 depending on provider/JSON mode.
  static bool _safeBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.trim().toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return false;
  }

  /// Fold a model's confidence to the 0.0–1.0 range the UI expects.
  /// Models are inconsistent: some return 0–1 (0.75), others a percentage
  /// (75), and the occasional double-percent (7500). Without this the badge
  /// showed values like "%7000". Each `/100` step undoes one percent scaling;
  /// the result is clamped to [0, 1].
  static double _normalizeConfidence(dynamic value) {
    var c = _number(value);
    if (c > 1.0) c = c / 100.0;
    if (c > 1.0) c = c / 100.0;
    return c.clamp(0.0, 1.0);
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

  /// Per-person realistic portion bounds. The model is already prompted
  /// to estimate "what one adult eats" (and to cap shared dishes at a
  /// single person's share), but we clamp defensively in case it returns
  /// an outlier — e.g. a serving-platter total or a misread label.
  /// 50g floor stops drink-only or appetiser-sized portions from looking
  /// negligible; 350g ceiling covers a hearty Turkish main without
  /// blessing values that would only make sense as 2-person totals.
  static const int _mealPortionFloor = 50;
  static const int _mealPortionCeiling = 350;

  static int _normalizeMealPortionGrams(int portionGrams) {
    if (portionGrams <= 0) return 200; // sensible default when AI omits
    if (portionGrams < _mealPortionFloor) return _mealPortionFloor;
    if (portionGrams > _mealPortionCeiling) return _mealPortionCeiling;
    return portionGrams;
  }

  /// Scale the model's nutrition payload to match the clamped portion.
  /// The prompt asks the model to return totals for the portion it
  /// estimated, so a clamp from 500g to 350g should drop nutrition to
  /// 350/500 = 0.7×. When the model is already inside the bounds the
  /// scale is 1.0 and the data passes through unchanged.
  static double _mealNutritionScale(int portionGrams) {
    if (portionGrams <= 0) return 1; // default-200g path uses raw values
    if (portionGrams < _mealPortionFloor) return _mealPortionFloor / portionGrams;
    if (portionGrams > _mealPortionCeiling) {
      return _mealPortionCeiling / portionGrams;
    }
    return 1;
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

String _mealAnalysisPrompt(String languageCode) {
  final languageName = _languageName(languageCode);
  return '''
Bu görseldeki öğünü analiz et. Amacın TEK KİŞİNİN yediği porsiyonu
gramaj + besin değeri olarak döndürmek.

Yanıt dili: $languageName. `food_name`, `ingredients_text` ve
`description` alanlarını $languageName dilinde yaz (yemek adını da bu dile
çevir; örn. İngilizce için "Etli Pilav" → "Rice with Meat").

ÖNEMLİ — önce ürün tipini belirle: Bu görsel hazır/pişmiş bir yemek/öğün mü
(tabak, kase, porsiyon), yoksa PAKETLİ/MARKALI bir market ürünü mü (kutu,
paket, şişe, teneke, kavanoz; üzerinde marka logosu, etiket veya barkod olan
satın alınmış ambalajlı ürün)? Paketli ürünse `is_packaged_product` alanını
true yap (yemek değilse bile diğer alanları elinden geldiğince doldur). Hazır
yemek/tabak ise false.

Önce şu kararı ver:
1. BİREYSEL porsiyon mu? (Bir kişinin önünde duran, tek başına yeneceği
   bir kase/tabak. Genelde çorba kasesi, salata tabağı, kahvaltı tabağı,
   tek bir ana yemek tabağı.)
2. PAYLAŞIMLI tabak/tencere mi? (Ortaya konmuş büyük servis tabağı,
   tencere, sini, börek tepsisi, pizza, ızgara tabağı, meze platter'ı —
   birden fazla kişinin bölüşmesi için.)

PAYLAŞIMLI ise: Sadece BİR kişinin alacağı tipik porsiyonu hesapla
(yaklaşık 150–250 g). Tabaktaki toplam yemeği DEĞİL.

BİREYSEL ise: Görseldeki gerçek miktarı tahmin et — tabak boyutu, dolma
seviyesi, kullanılan kap.

Yiyecek tipi referans aralıkları (bir kişilik):
  * Ana yemek (et, balık, tavuk vs.): 150–250 g
  * Pilav / makarna / kuru baklagil garnitürü: 80–150 g
  * Pilav / makarna ana yemek olarak: 200–300 g
  * Çorba: 250–350 ml
  * Salata / meze: 80–150 g
  * Sandviç / dürüm / börek: 150–250 g
  * Pizza dilimi: 100–180 g
  * Tatlı / pasta: 80–150 g
  * Atıştırmalık: 30–80 g
  * Kahvaltı tabağı (karışık): 150–250 g
  * İçecek: 200–400 ml

Sert kurallar:
- 50 g'dan az veya 350 g'dan fazla TEK KİŞİLİK porsiyon DÖNDÜRME. Bu
  bandın dışına çıkarsan değerler reddedilir.
- Default olarak 100 g sabiti KULLANMA. Fotoğrafa ve yemek tipine bak.
- `portion_grams`: bir kişinin yediği toplam gramaj.
- `nutrition`: o porsiyonun TOPLAM besin değerleri (100 g için değil).
- İçindekileri ($languageName) düz metin olarak yaz.
- `confidence`: 0.0 ile 1.0 ARASINDA ondalık sayı (örn. 0.75). Yüzde (75) DEĞİL.
- Belirsizse yine en iyi tahmini yap, `confidence` düşük olur.
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
  "description": string,
  "is_packaged_product": boolean
}
''';
}
