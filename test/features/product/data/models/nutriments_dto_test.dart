import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/product/data/models/nutriments_dto.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:openfoodfacts/openfoodfacts.dart';

void main() {
  group('NutrimentsDto.fromOffNutriments', () {
    test('returns empty entity for null input', () {
      final entity = NutrimentsDto.fromOffNutriments(null);

      expect(entity, const NutrimentsEntity());
    });

    test('maps all nutrient values from OFF Nutriments', () {
      final offNutriments = Nutriments.empty()
        ..setValue(Nutrient.energyKCal, PerSize.oneHundredGrams, 250.0)
        ..setValue(Nutrient.fat, PerSize.oneHundredGrams, 10.5)
        ..setValue(Nutrient.saturatedFat, PerSize.oneHundredGrams, 3.2)
        ..setValue(Nutrient.sugars, PerSize.oneHundredGrams, 12.0)
        ..setValue(Nutrient.salt, PerSize.oneHundredGrams, 1.5)
        ..setValue(Nutrient.fiber, PerSize.oneHundredGrams, 4.0)
        ..setValue(Nutrient.proteins, PerSize.oneHundredGrams, 8.0);

      final entity = NutrimentsDto.fromOffNutriments(offNutriments);

      expect(entity.energyKcal, 250.0);
      expect(entity.fat, 10.5);
      expect(entity.saturatedFat, 3.2);
      expect(entity.sugars, 12.0);
      expect(entity.salt, 1.5);
      expect(entity.fiber, 4.0);
      expect(entity.proteins, 8.0);
    });

    test('returns null for missing nutrient values', () {
      final offNutriments = Nutriments.empty()
        ..setValue(Nutrient.energyKCal, PerSize.oneHundredGrams, 100.0);

      final entity = NutrimentsDto.fromOffNutriments(offNutriments);

      expect(entity.energyKcal, 100.0);
      expect(entity.fat, isNull);
      expect(entity.proteins, isNull);
    });
  });

  group('NutrimentsDto.toJsonString', () {
    test('converts full entity to JSON string', () {
      const entity = NutrimentsEntity(
        energyKcal: 250.0,
        fat: 10.5,
        saturatedFat: 3.2,
        sugars: 12.0,
        salt: 1.5,
        fiber: 4.0,
        proteins: 8.0,
      );

      final jsonStr = NutrimentsDto.toJsonString(entity);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['energy_kcal'], 250.0);
      expect(map['fat'], 10.5);
      expect(map['saturated_fat'], 3.2);
      expect(map['sugars'], 12.0);
      expect(map['salt'], 1.5);
      expect(map['fiber'], 4.0);
      expect(map['proteins'], 8.0);
    });

    test('converts empty entity to JSON with nulls', () {
      const entity = NutrimentsEntity();

      final jsonStr = NutrimentsDto.toJsonString(entity);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['energy_kcal'], isNull);
      expect(map['fat'], isNull);
      expect(map['saturated_fat'], isNull);
      expect(map['sugars'], isNull);
      expect(map['salt'], isNull);
      expect(map['fiber'], isNull);
      expect(map['proteins'], isNull);
    });

    test('handles partial entity', () {
      const entity = NutrimentsEntity(energyKcal: 100.0, proteins: 5.0);

      final jsonStr = NutrimentsDto.toJsonString(entity);
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['energy_kcal'], 100.0);
      expect(map['proteins'], 5.0);
      expect(map['fat'], isNull);
    });
  });

  group('NutrimentsDto.fromJsonString', () {
    test('parses full JSON string', () {
      final jsonStr = jsonEncode({
        'energy_kcal': 250.0,
        'fat': 10.5,
        'saturated_fat': 3.2,
        'sugars': 12.0,
        'salt': 1.5,
        'fiber': 4.0,
        'proteins': 8.0,
      });

      final entity = NutrimentsDto.fromJsonString(jsonStr);

      expect(entity.energyKcal, 250.0);
      expect(entity.fat, 10.5);
      expect(entity.saturatedFat, 3.2);
      expect(entity.sugars, 12.0);
      expect(entity.salt, 1.5);
      expect(entity.fiber, 4.0);
      expect(entity.proteins, 8.0);
    });

    test('returns empty entity for empty string', () {
      final entity = NutrimentsDto.fromJsonString('');

      expect(entity, const NutrimentsEntity());
    });

    test('returns empty entity for empty object string', () {
      final entity = NutrimentsDto.fromJsonString('{}');

      expect(entity, const NutrimentsEntity());
    });

    test('handles integer values cast to double', () {
      final jsonStr = jsonEncode({
        'energy_kcal': 250,
        'fat': 10,
        'saturated_fat': null,
        'sugars': null,
        'salt': null,
        'fiber': null,
        'proteins': null,
      });

      final entity = NutrimentsDto.fromJsonString(jsonStr);

      expect(entity.energyKcal, 250.0);
      expect(entity.fat, 10.0);
    });

    test('handles null values in JSON', () {
      final jsonStr = jsonEncode({
        'energy_kcal': null,
        'fat': null,
        'saturated_fat': null,
        'sugars': null,
        'salt': null,
        'fiber': null,
        'proteins': null,
      });

      final entity = NutrimentsDto.fromJsonString(jsonStr);

      expect(entity.energyKcal, isNull);
      expect(entity.fat, isNull);
    });

    test('handles missing keys in JSON', () {
      final jsonStr = jsonEncode({'energy_kcal': 100.0});

      final entity = NutrimentsDto.fromJsonString(jsonStr);

      expect(entity.energyKcal, 100.0);
      expect(entity.fat, isNull);
      expect(entity.proteins, isNull);
    });
  });

  group('NutrimentsDto roundtrip', () {
    test('toJsonString then fromJsonString preserves data', () {
      const original = NutrimentsEntity(
        energyKcal: 123.4,
        fat: 5.6,
        saturatedFat: 2.1,
        sugars: 8.9,
        salt: 0.7,
        fiber: 3.3,
        proteins: 11.2,
      );

      final jsonStr = NutrimentsDto.toJsonString(original);
      final restored = NutrimentsDto.fromJsonString(jsonStr);

      expect(restored, equals(original));
    });

    test('roundtrip preserves empty entity', () {
      const original = NutrimentsEntity();

      final jsonStr = NutrimentsDto.toJsonString(original);
      final restored = NutrimentsDto.fromJsonString(jsonStr);

      expect(restored, equals(original));
    });
  });
}
