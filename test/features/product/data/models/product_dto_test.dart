import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/product/data/models/product_dto.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';
import 'package:openfoodfacts/openfoodfacts.dart';

void main() {
  group('ProductDto.fromOffProduct', () {
    test('maps all fields from OFF Product', () {
      final offNutriments = Nutriments.empty()
        ..setValue(Nutrient.energyKCal, PerSize.oneHundredGrams, 200.0)
        ..setValue(Nutrient.fat, PerSize.oneHundredGrams, 8.0);

      final offProduct = Product()
        ..barcode = '8690000000001'
        ..productName = 'Test Product'
        ..brands = 'Test Brand'
        ..imageFrontUrl = 'https://example.com/img.jpg'
        ..ingredientsText = 'water, sugar'
        ..allergens = Allergens(['en:milk', 'en:gluten'], ['milk', 'gluten'])
        ..additives = Additives(['en:e300'], ['E300'])
        ..novaGroup = 3
        ..nutriscore = 'b'
        ..nutriments = offNutriments
        ..categoriesTags = ['en:snacks']
        ..countriesTags = ['en:turkey'];

      final entity = ProductDto.fromOffProduct(offProduct);

      expect(entity.barcode, '8690000000001');
      expect(entity.productName, 'Test Product');
      expect(entity.brands, 'Test Brand');
      expect(entity.imageUrl, 'https://example.com/img.jpg');
      expect(entity.ingredientsText, 'water, sugar');
      expect(entity.allergensTags, ['en:milk', 'en:gluten']);
      expect(entity.additivesTags, ['en:e300']);
      expect(entity.novaGroup, 3);
      expect(entity.nutriscoreGrade, 'b');
      expect(entity.nutriments.energyKcal, 200.0);
      expect(entity.nutriments.fat, 8.0);
      expect(entity.categoriesTags, ['en:snacks']);
      expect(entity.countriesTags, ['en:turkey']);
    });

    test('handles null/empty OFF Product fields', () {
      final offProduct = Product()..barcode = '123';

      final entity = ProductDto.fromOffProduct(offProduct);

      expect(entity.barcode, '123');
      expect(entity.productName, isNull);
      expect(entity.brands, isNull);
      expect(entity.allergensTags, isEmpty);
      expect(entity.additivesTags, isEmpty);
      expect(entity.novaGroup, isNull);
      expect(entity.categoriesTags, isEmpty);
      expect(entity.countriesTags, isEmpty);
    });

    test('handles null barcode as empty string', () {
      final offProduct = Product();

      final entity = ProductDto.fromOffProduct(offProduct);

      expect(entity.barcode, '');
    });
  });

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
    ingredientsText: 'water, sugar',
    allergensTags: ['en:milk', 'en:gluten'],
    additivesTags: ['en:e300'],
    novaGroup: 2,
    nutriscoreGrade: 'a',
    nutriments: nutriments,
    categoriesTags: ['en:snacks'],
    countriesTags: ['en:turkey'],
    hpScore: 80.0,
    hpChemicalLoad: 90.0,
    hpRiskFactor: 70.0,
    hpNutriFactor: 75.0,
  );

  group('ProductDto.fromDriftRow', () {
    test('maps all fields correctly', () {
      final entity = ProductDto.fromDriftRow(
        barcode: '8690000000001',
        productName: 'Test Product',
        brands: 'Test Brand',
        imageUrl: 'https://example.com/img.jpg',
        ingredientsText: 'water, sugar',
        allergensTags: '["en:milk","en:gluten"]',
        additivesTags: '["en:e300"]',
        novaGroup: 2,
        nutriscoreGrade: 'a',
        nutriments: jsonEncode({
          'energy_kcal': 200.0,
          'fat': 8.0,
          'saturated_fat': 2.0,
          'sugars': 10.0,
          'salt': 1.0,
          'fiber': 3.0,
          'proteins': 7.0,
        }),
        categoriesTags: '["en:snacks"]',
        countriesTags: '["en:turkey"]',
        hpScore: 80.0,
        hpChemicalLoad: 90.0,
        hpRiskFactor: 70.0,
        hpNutriFactor: 75.0,
      );

      expect(entity.barcode, '8690000000001');
      expect(entity.productName, 'Test Product');
      expect(entity.allergensTags, ['en:milk', 'en:gluten']);
      expect(entity.additivesTags, ['en:e300']);
      expect(entity.nutriments, nutriments);
      expect(entity.hpScore, 80.0);
    });

    test('handles empty JSON arrays', () {
      final entity = ProductDto.fromDriftRow(
        barcode: '123',
        allergensTags: '[]',
        additivesTags: '[]',
        nutriments: '{}',
        categoriesTags: '[]',
        countriesTags: '[]',
      );

      expect(entity.allergensTags, isEmpty);
      expect(entity.additivesTags, isEmpty);
      expect(entity.categoriesTags, isEmpty);
      expect(entity.countriesTags, isEmpty);
    });

    test('handles empty string for lists', () {
      final entity = ProductDto.fromDriftRow(
        barcode: '123',
        allergensTags: '',
        additivesTags: '',
        nutriments: '',
        categoriesTags: '',
        countriesTags: '',
      );

      expect(entity.allergensTags, isEmpty);
      expect(entity.additivesTags, isEmpty);
    });

    test('handles null optional fields', () {
      final entity = ProductDto.fromDriftRow(
        barcode: '123',
        allergensTags: '[]',
        additivesTags: '[]',
        nutriments: '{}',
        categoriesTags: '[]',
        countriesTags: '[]',
      );

      expect(entity.productName, isNull);
      expect(entity.brands, isNull);
      expect(entity.novaGroup, isNull);
      expect(entity.hpScore, isNull);
    });
  });

}
