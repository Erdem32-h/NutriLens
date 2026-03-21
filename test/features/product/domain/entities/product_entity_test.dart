import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';

void main() {
  const nutriments = NutrimentsEntity(
    energyKcal: 200.0,
    fat: 8.0,
    saturatedFat: 2.0,
    sugars: 10.0,
    salt: 1.0,
    fiber: 3.0,
    proteins: 7.0,
  );

  const product = ProductEntity(
    barcode: '8690000000001',
    productName: 'Test Product',
    brands: 'Test Brand',
    imageUrl: 'https://example.com/img.jpg',
    ingredientsText: 'water, sugar, salt',
    allergensTags: ['en:milk', 'en:gluten'],
    additivesTags: ['en:e300', 'en:e330'],
    novaGroup: 3,
    nutriscoreGrade: 'b',
    nutriments: nutriments,
    categoriesTags: ['en:snacks'],
    countriesTags: ['en:turkey'],
    hpScore: 72.5,
    hpChemicalLoad: 85.0,
    hpRiskFactor: 65.0,
    hpNutriFactor: 70.0,
  );

  group('ProductEntity', () {
    test('stores all fields', () {
      expect(product.barcode, '8690000000001');
      expect(product.productName, 'Test Product');
      expect(product.brands, 'Test Brand');
      expect(product.imageUrl, 'https://example.com/img.jpg');
      expect(product.ingredientsText, 'water, sugar, salt');
      expect(product.allergensTags, ['en:milk', 'en:gluten']);
      expect(product.additivesTags, ['en:e300', 'en:e330']);
      expect(product.novaGroup, 3);
      expect(product.nutriscoreGrade, 'b');
      expect(product.nutriments, nutriments);
      expect(product.categoriesTags, ['en:snacks']);
      expect(product.countriesTags, ['en:turkey']);
      expect(product.hpScore, 72.5);
      expect(product.hpChemicalLoad, 85.0);
      expect(product.hpRiskFactor, 65.0);
      expect(product.hpNutriFactor, 70.0);
    });

    test('optional fields default correctly', () {
      const minimal = ProductEntity(barcode: '123');

      expect(minimal.productName, isNull);
      expect(minimal.brands, isNull);
      expect(minimal.imageUrl, isNull);
      expect(minimal.ingredientsText, isNull);
      expect(minimal.allergensTags, isEmpty);
      expect(minimal.additivesTags, isEmpty);
      expect(minimal.novaGroup, isNull);
      expect(minimal.nutriscoreGrade, isNull);
      expect(minimal.nutriments, const NutrimentsEntity());
      expect(minimal.categoriesTags, isEmpty);
      expect(minimal.countriesTags, isEmpty);
      expect(minimal.hpScore, isNull);
      expect(minimal.hpChemicalLoad, isNull);
      expect(minimal.hpRiskFactor, isNull);
      expect(minimal.hpNutriFactor, isNull);
    });

    test('equality based on all props', () {
      const same = ProductEntity(
        barcode: '8690000000001',
        productName: 'Test Product',
        brands: 'Test Brand',
        imageUrl: 'https://example.com/img.jpg',
        ingredientsText: 'water, sugar, salt',
        allergensTags: ['en:milk', 'en:gluten'],
        additivesTags: ['en:e300', 'en:e330'],
        novaGroup: 3,
        nutriscoreGrade: 'b',
        nutriments: nutriments,
        categoriesTags: ['en:snacks'],
        countriesTags: ['en:turkey'],
        hpScore: 72.5,
        hpChemicalLoad: 85.0,
        hpRiskFactor: 65.0,
        hpNutriFactor: 70.0,
      );

      expect(product, equals(same));
    });

    test('inequality when barcode differs', () {
      const different = ProductEntity(barcode: '9999999999999');

      expect(product, isNot(equals(different)));
    });
  });

  group('ProductEntity.copyWith', () {
    test('updates barcode', () {
      final updated = product.copyWith(barcode: 'new-barcode');

      expect(updated.barcode, 'new-barcode');
      expect(updated.productName, product.productName);
    });

    test('updates productName', () {
      final updated = product.copyWith(productName: 'New Name');

      expect(updated.productName, 'New Name');
    });

    test('updates hpScore', () {
      final updated = product.copyWith(hpScore: 99.9);

      expect(updated.hpScore, 99.9);
    });

    test('updates allergensTags', () {
      final updated = product.copyWith(allergensTags: ['en:soy']);

      expect(updated.allergensTags, ['en:soy']);
    });

    test('updates nutriments', () {
      const newNutriments = NutrimentsEntity(energyKcal: 500.0);
      final updated = product.copyWith(nutriments: newNutriments);

      expect(updated.nutriments, newNutriments);
    });

    test('preserves all fields when no arguments given', () {
      final copy = product.copyWith();

      expect(copy, equals(product));
      expect(identical(copy, product), isFalse);
    });
  });
}
