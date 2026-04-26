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
