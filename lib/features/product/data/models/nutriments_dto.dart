import 'dart:convert';

import 'package:openfoodfacts/openfoodfacts.dart';

import '../../domain/entities/nutriments_entity.dart';

abstract final class NutrimentsDto {
  /// Maps OFF SDK [Nutriments] to our [NutrimentsEntity].
  static NutrimentsEntity fromOffNutriments(Nutriments? nutriments) {
    if (nutriments == null) {
      return const NutrimentsEntity();
    }

    return NutrimentsEntity(
      energyKcal: nutriments.getValue(
        Nutrient.energyKCal,
        PerSize.oneHundredGrams,
      ),
      fat: nutriments.getValue(Nutrient.fat, PerSize.oneHundredGrams),
      saturatedFat: nutriments.getValue(
        Nutrient.saturatedFat,
        PerSize.oneHundredGrams,
      ),
      sugars: nutriments.getValue(Nutrient.sugars, PerSize.oneHundredGrams),
      salt: nutriments.getValue(Nutrient.salt, PerSize.oneHundredGrams),
      fiber: nutriments.getValue(Nutrient.fiber, PerSize.oneHundredGrams),
      proteins: nutriments.getValue(
        Nutrient.proteins,
        PerSize.oneHundredGrams,
      ),
    );
  }

  /// Converts a [NutrimentsEntity] to a JSON string for Drift storage.
  static String toJsonString(NutrimentsEntity entity) {
    return jsonEncode({
      'energy_kcal': entity.energyKcal,
      'fat': entity.fat,
      'saturated_fat': entity.saturatedFat,
      'sugars': entity.sugars,
      'salt': entity.salt,
      'fiber': entity.fiber,
      'proteins': entity.proteins,
    });
  }

  /// Parses a JSON string from Drift into a [NutrimentsEntity].
  static NutrimentsEntity fromJsonString(String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == '{}') {
      return const NutrimentsEntity();
    }

    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return NutrimentsEntity(
      energyKcal: (map['energy_kcal'] as num?)?.toDouble(),
      fat: (map['fat'] as num?)?.toDouble(),
      saturatedFat: (map['saturated_fat'] as num?)?.toDouble(),
      sugars: (map['sugars'] as num?)?.toDouble(),
      salt: (map['salt'] as num?)?.toDouble(),
      fiber: (map['fiber'] as num?)?.toDouble(),
      proteins: (map['proteins'] as num?)?.toDouble(),
    );
  }
}
