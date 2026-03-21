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

  group('ProductDto.toDriftMap', () {
    test('maps all fields correctly', () {
      final map = ProductDto.toDriftMap(product);

      expect(map['barcode'], '8690000000001');
      expect(map['productName'], 'Test Product');
      expect(map['brands'], 'Test Brand');
      expect(map['imageUrl'], 'https://example.com/img.jpg');
      expect(map['ingredientsText'], 'water, sugar');
      expect(map['novaGroup'], 2);
      expect(map['nutriscoreGrade'], 'a');
      expect(map['hpScore'], 80.0);
      expect(map['hpChemicalLoad'], 90.0);
      expect(map['hpRiskFactor'], 70.0);
      expect(map['hpNutriFactor'], 75.0);
      expect(map['cachedAt'], isA<DateTime>());
    });

    test('serializes list fields as JSON strings', () {
      final map = ProductDto.toDriftMap(product);

      final allergens = jsonDecode(map['allergensTags'] as String) as List;
      expect(allergens, ['en:milk', 'en:gluten']);

      final additives = jsonDecode(map['additivesTags'] as String) as List;
      expect(additives, ['en:e300']);

      final categories = jsonDecode(map['categoriesTags'] as String) as List;
      expect(categories, ['en:snacks']);

      final countries = jsonDecode(map['countriesTags'] as String) as List;
      expect(countries, ['en:turkey']);
    });

    test('serializes nutriments as JSON string', () {
      final map = ProductDto.toDriftMap(product);
      final nutrimentsJson =
          jsonDecode(map['nutriments'] as String) as Map<String, dynamic>;

      expect(nutrimentsJson['energy_kcal'], 200.0);
      expect(nutrimentsJson['fat'], 8.0);
    });

    test('handles empty lists', () {
      const minimal = ProductEntity(barcode: '123');
      final map = ProductDto.toDriftMap(minimal);

      final allergens = jsonDecode(map['allergensTags'] as String) as List;
      expect(allergens, isEmpty);
    });

    test('handles null optional fields', () {
      const minimal = ProductEntity(barcode: '123');
      final map = ProductDto.toDriftMap(minimal);

      expect(map['productName'], isNull);
      expect(map['brands'], isNull);
      expect(map['imageUrl'], isNull);
      expect(map['novaGroup'], isNull);
      expect(map['hpScore'], isNull);
    });
  });

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

  group('ProductDto roundtrip (toDriftMap -> fromDriftRow)', () {
    test('preserves data through serialization cycle', () {
      final map = ProductDto.toDriftMap(product);

      final restored = ProductDto.fromDriftRow(
        barcode: map['barcode'] as String,
        productName: map['productName'] as String?,
        brands: map['brands'] as String?,
        imageUrl: map['imageUrl'] as String?,
        ingredientsText: map['ingredientsText'] as String?,
        allergensTags: map['allergensTags'] as String,
        additivesTags: map['additivesTags'] as String,
        novaGroup: map['novaGroup'] as int?,
        nutriscoreGrade: map['nutriscoreGrade'] as String?,
        nutriments: map['nutriments'] as String,
        categoriesTags: map['categoriesTags'] as String,
        countriesTags: map['countriesTags'] as String,
        hpScore: map['hpScore'] as double?,
        hpChemicalLoad: map['hpChemicalLoad'] as double?,
        hpRiskFactor: map['hpRiskFactor'] as double?,
        hpNutriFactor: map['hpNutriFactor'] as double?,
      );

      expect(restored.barcode, product.barcode);
      expect(restored.productName, product.productName);
      expect(restored.brands, product.brands);
      expect(restored.allergensTags, product.allergensTags);
      expect(restored.additivesTags, product.additivesTags);
      expect(restored.nutriments, product.nutriments);
      expect(restored.hpScore, product.hpScore);
      expect(restored.hpChemicalLoad, product.hpChemicalLoad);
      expect(restored.hpRiskFactor, product.hpRiskFactor);
      expect(restored.hpNutriFactor, product.hpNutriFactor);
    });
  });
}
