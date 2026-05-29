import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:nutrilens/core/services/anthropic_ai_service.dart';

void main() {
  group('AnthropicAiService.parseNutritionResponseText', () {
    test('parses fenced JSON nutrition response', () {
      final result = AnthropicAiService.parseNutritionResponseText('''
```json
{
  "energy_kcal": 438,
  "fat": 16,
  "saturated_fat": 6.4,
  "trans_fat": 0,
  "carbohydrates": 63,
  "sugars": 31,
  "salt": 0.42,
  "fiber": 2.1,
  "protein": 7.5
}
```
''');

      expect(result, isNotNull);
      expect(result!.energyKcal, 438);
      expect(result.fat, 16);
      expect(result.saturatedFat, 6.4);
      expect(result.transFat, 0);
      expect(result.carbohydrates, 63);
      expect(result.sugars, 31);
      expect(result.salt, 0.42);
      expect(result.fiber, 2.1);
      expect(result.protein, 7.5);
    });

    test('defaults missing nutrition values to zero', () {
      final result = AnthropicAiService.parseNutritionResponseText('{}');

      expect(result, isNotNull);
      expect(result!.energyKcal, 0);
      expect(result.fat, 0);
      expect(result.saturatedFat, 0);
      expect(result.transFat, 0);
      expect(result.carbohydrates, 0);
      expect(result.sugars, 0);
      expect(result.salt, 0);
      expect(result.fiber, 0);
      expect(result.protein, 0);
    });
  });

  group('AnthropicAiService.parseIngredientsResponseText', () {
    test('returns trimmed ingredients and allergen text', () {
      final result = AnthropicAiService.parseIngredientsResponseText('''
İçindekiler: Buğday unu, şeker, fındık, süt tozu.
Alerjenler: Gluten, fındık, süt.
''');

      expect(
        result,
        'İçindekiler: Buğday unu, şeker, fındık, süt tozu.\n'
        'Alerjenler: Gluten, fındık, süt.',
      );
    });

    test('returns null when Claude reports no ingredients text', () {
      final result = AnthropicAiService.parseIngredientsResponseText(
        'ICINDEKILER_BULUNAMADI',
      );

      expect(result, isNull);
    });
  });

  group('AnthropicAiService.parseMealAnalysisResponseText', () {
    test('parses meal analysis JSON with ingredients and nutrition', () {
      final result = AnthropicAiService.parseMealAnalysisResponseText('''
```json
{
  "food_name": "Menemen ve ekmek",
  "portion_grams": 420,
  "ingredients_text": "Yumurta, domates, biber, zeytinyağı, ekmek",
  "nutrition": {
    "energy_kcal": 610,
    "fat": 28,
    "saturated_fat": 6,
    "trans_fat": 0,
    "carbohydrates": 55,
    "sugars": 8,
    "salt": 1.7,
    "fiber": 6,
    "protein": 28
  },
  "confidence": 0.72,
  "description": "Ev tipi karışık öğün tahmini."
}
```
''');

      expect(result, isNotNull);
      expect(result!.foodName, 'Menemen ve ekmek');
      // 420g exceeds the 350g per-person ceiling → clamped to 350 and the
      // nutrition is scaled by 350/420 = 0.8333.
      expect(result.portionGrams, 350);
      expect(result.ingredientsText, contains('Yumurta'));
      expect(result.nutriments.energyKcal, 508.33);
      expect(result.nutriments.carbohydrates, 45.83);
      expect(result.confidence, 0.72);
    });

    test('defaults missing meal nutrition values to zero', () {
      final result = AnthropicAiService.parseMealAnalysisResponseText('{}');

      expect(result, isNotNull);
      expect(result!.foodName, 'Bilinmeyen Öğün');
      expect(result.nutriments.energyKcal, 0);
      expect(result.nutriments.proteins, 0);
      expect(result.ingredientsText, isNull);
    });

    test(
      'normalizes oversized visible portions to the 350g personal ceiling',
      () {
        final result = AnthropicAiService.parseMealAnalysisResponseText('''
{
  "food_name": "Tencere yemeği",
  "portion_grams": 500,
  "ingredients_text": "Et, sebze, yağ",
  "nutrition": {
    "energy_kcal": 750,
    "fat": 35,
    "saturated_fat": 10,
    "trans_fat": 0,
    "carbohydrates": 60,
    "sugars": 15,
    "salt": 4,
    "fiber": 8,
    "protein": 40
  },
  "confidence": 0.6,
  "description": "Büyük kapta görünen toplam yemek."
}
''');

        expect(result, isNotNull);
        // 500g → clamped to the 350g ceiling, nutrition scaled by 350/500 = 0.7.
        expect(result!.portionGrams, 350);
        expect(result.nutriments.energyKcal, 525);
        expect(result.nutriments.fat, 24.5);
        expect(result.nutriments.salt, 2.8);
        expect(result.nutriments.proteins, 28);
      },
    );
  });

  group('AnthropicAiService.parseRecalcResponseText', () {
    test('parses v3 schema with nested nutrition + portion_grams', () {
      final result = AnthropicAiService.parseRecalcResponseText('''
{
  "portion_grams": 250,
  "nutrition": {
    "energy_kcal": 380,
    "fat": 12,
    "saturated_fat": 4,
    "trans_fat": 0,
    "carbohydrates": 50,
    "sugars": 8,
    "salt": 1.2,
    "fiber": 5,
    "protein": 20
  }
}
''');

      expect(result, isNotNull);
      expect(result!.portionGrams, 250);
      expect(result.nutriments.energyKcal, 380);
      expect(result.nutriments.fat, 12);
      expect(result.nutriments.proteins, 20);
    });

    test('falls back to legacy flat schema (backward compat)', () {
      // Pre-v3 prompt put nutrition fields at the top level. The
      // parser keeps reading that shape so an old cached response
      // doesn't crash the meal screen.
      final result = AnthropicAiService.parseRecalcResponseText('''
{
  "energy_kcal": 300,
  "fat": 10,
  "saturated_fat": 3,
  "trans_fat": 0,
  "carbohydrates": 40,
  "sugars": 5,
  "salt": 1,
  "fiber": 4,
  "protein": 15
}
''');

      expect(result, isNotNull);
      expect(
        result!.portionGrams,
        0,
        reason: 'flat schema has no portion_grams — caller falls back',
      );
      expect(result.nutriments.energyKcal, 300);
      expect(result.nutriments.proteins, 15);
    });

    test('handles fenced ```json blocks', () {
      final result = AnthropicAiService.parseRecalcResponseText('''
Some preamble Claude sometimes adds:
```json
{
  "portion_grams": 150,
  "nutrition": {"energy_kcal": 200}
}
```
''');

      expect(result, isNotNull);
      expect(result!.portionGrams, 150);
      expect(result.nutriments.energyKcal, 200);
    });

    test('returns null on unparseable garbage', () {
      expect(AnthropicAiService.parseRecalcResponseText(''), isNull);
      expect(
        AnthropicAiService.parseRecalcResponseText('not json at all'),
        isNull,
      );
    });

    test('accepts comma-decimal European numbers as strings', () {
      // Claude occasionally emits "12,5" for fat values when the
      // source nutrition label uses comma decimals.
      final result = AnthropicAiService.parseRecalcResponseText('''
{
  "portion_grams": 100,
  "nutrition": {
    "energy_kcal": "412",
    "fat": "12,5",
    "saturated_fat": "3,2"
  }
}
''');
      expect(result, isNotNull);
      expect(result!.nutriments.energyKcal, 412);
      expect(result.nutriments.fat, 12.5);
      expect(result.nutriments.saturatedFat, 3.2);
    });
  });

  group('AnthropicAiService vision requests', () {
    test('retries transient Anthropic failures once and returns text', () async {
      final adapter = _FakeAnthropicAdapter([
        ResponseBody.fromString(
          '{"error":{"message":"rate limited"}}',
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
        ResponseBody.fromString(
          '{"content":[{"type":"text","text":"İçindekiler: Buğday unu\\nAlerjenler: Gluten"}]}',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = AnthropicAiService(dio: dio, apiKey: 'test-key');

      final result = await service.extractIngredientsFromBase64(
        'abc123',
        languageCode: 'tr',
      );

      expect(result, contains('İçindekiler'));
      expect(adapter.requestCount, 2);
    });

    test('does not retry unauthorized Anthropic failures', () async {
      final adapter = _FakeAnthropicAdapter([
        ResponseBody.fromString(
          '{"error":{"message":"invalid api key"}}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = AnthropicAiService(dio: dio, apiKey: 'bad-key');

      await expectLater(
        service.extractNutritionFromBase64('abc123'),
        throwsA(
          isA<AnthropicServiceException>().having(
            (e) => e.statusCode,
            'statusCode',
            401,
          ),
        ),
      );
      expect(adapter.requestCount, 1);
    });
  });
}

class _FakeAnthropicAdapter extends IOHttpClientAdapter {
  final List<ResponseBody> responses;
  int requestCount = 0;

  _FakeAnthropicAdapter(this.responses);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final index = requestCount++;
    return responses[index.clamp(0, responses.length - 1)];
  }
}
