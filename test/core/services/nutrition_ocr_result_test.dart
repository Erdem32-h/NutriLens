import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/gemini_ai_service.dart';

void main() {
  group('NutritionOcrResult.fromJson', () {
    test('parses plain JSON numbers', () {
      final r = NutritionOcrResult.fromJson(const {
        'energy_kcal': 518,
        'fat': 27.5,
        'salt': 0.42,
      });
      expect(r.energyKcal, 518);
      expect(r.fat, 27.5);
      expect(r.salt, 0.42);
      expect(r.protein, isNull);
    });

    test('parses quantities the model quoted as strings', () {
      // Exactly what the 2026-07-22 thinking-budget experiment produced:
      // correct values, wrong JSON type. Must not null the scan.
      final r = NutritionOcrResult.fromJson(const {
        'energy_kcal': '518',
        'fat': '27.5',
        'trans_fat': '0',
        'salt': '0,42', // Turkish decimal comma
      });
      expect(r.energyKcal, 518);
      expect(r.fat, 27.5);
      expect(r.transFat, 0);
      expect(r.salt, 0.42);
    });

    test('maps null, junk strings and unexpected types to null', () {
      final r = NutritionOcrResult.fromJson(const {
        'energy_kcal': null,
        'fat': 'iz miktar',
        'sugars': true,
        'protein': <int>[9],
      });
      expect(r.energyKcal, isNull);
      expect(r.fat, isNull);
      expect(r.sugars, isNull);
      expect(r.protein, isNull);
    });
  });
}
