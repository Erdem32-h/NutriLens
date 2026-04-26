import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

void main() {
  const nutriments = NutrimentsEntity(
    energyKcal: 250.0,
    fat: 10.5,
    saturatedFat: 3.2,
    transFat: 0.1,
    carbohydrates: 34.0,
    sugars: 12.0,
    salt: 1.5,
    fiber: 4.0,
    proteins: 8.0,
  );

  group('NutrimentsEntity', () {
    test('stores all fields', () {
      expect(nutriments.energyKcal, 250.0);
      expect(nutriments.fat, 10.5);
      expect(nutriments.saturatedFat, 3.2);
      expect(nutriments.transFat, 0.1);
      expect(nutriments.carbohydrates, 34.0);
      expect(nutriments.sugars, 12.0);
      expect(nutriments.salt, 1.5);
      expect(nutriments.fiber, 4.0);
      expect(nutriments.proteins, 8.0);
    });

    test('all fields default to null', () {
      const empty = NutrimentsEntity();

      expect(empty.energyKcal, isNull);
      expect(empty.fat, isNull);
      expect(empty.saturatedFat, isNull);
      expect(empty.sugars, isNull);
      expect(empty.salt, isNull);
      expect(empty.fiber, isNull);
      expect(empty.proteins, isNull);
    });

    test('empty static const is all nulls', () {
      expect(NutrimentsEntity.empty, const NutrimentsEntity());
    });

    test('equality based on all props', () {
      const same = NutrimentsEntity(
        energyKcal: 250.0,
        fat: 10.5,
        saturatedFat: 3.2,
        transFat: 0.1,
        carbohydrates: 34.0,
        sugars: 12.0,
        salt: 1.5,
        fiber: 4.0,
        proteins: 8.0,
      );

      expect(nutriments, equals(same));
    });

    test('inequality when any prop differs', () {
      const different = NutrimentsEntity(
        energyKcal: 999.0,
        fat: 10.5,
        saturatedFat: 3.2,
        transFat: 0.1,
        carbohydrates: 34.0,
        sugars: 12.0,
        salt: 1.5,
        fiber: 4.0,
        proteins: 8.0,
      );

      expect(nutriments, isNot(equals(different)));
    });

    test('props contains all fields in order', () {
      expect(
        nutriments.props,
        [250.0, 10.5, 3.2, 0.1, 34.0, 12.0, 1.5, 4.0, 8.0],
      );
    });
  });

  group('NutrimentsEntity.copyWith', () {
    test('returns new instance with updated energyKcal', () {
      final updated = nutriments.copyWith(energyKcal: 500.0);

      expect(updated.energyKcal, 500.0);
      expect(updated.fat, nutriments.fat);
    });

    test('returns new instance with updated fat', () {
      final updated = nutriments.copyWith(fat: 20.0);

      expect(updated.fat, 20.0);
    });

    test('returns new instance with updated saturatedFat', () {
      final updated = nutriments.copyWith(saturatedFat: 5.0);

      expect(updated.saturatedFat, 5.0);
    });

    test('returns new instance with updated transFat', () {
      final updated = nutriments.copyWith(transFat: 0.0);

      expect(updated.transFat, 0.0);
    });

    test('returns new instance with updated carbohydrates', () {
      final updated = nutriments.copyWith(carbohydrates: 42.0);

      expect(updated.carbohydrates, 42.0);
    });

    test('returns new instance with updated sugars', () {
      final updated = nutriments.copyWith(sugars: 0.0);

      expect(updated.sugars, 0.0);
    });

    test('returns new instance with updated salt', () {
      final updated = nutriments.copyWith(salt: 0.1);

      expect(updated.salt, 0.1);
    });

    test('returns new instance with updated fiber', () {
      final updated = nutriments.copyWith(fiber: 10.0);

      expect(updated.fiber, 10.0);
    });

    test('returns new instance with updated proteins', () {
      final updated = nutriments.copyWith(proteins: 25.0);

      expect(updated.proteins, 25.0);
    });

    test('preserves all fields when no arguments given', () {
      final copy = nutriments.copyWith();

      expect(copy, equals(nutriments));
      expect(identical(copy, nutriments), isFalse);
    });
  });
}
