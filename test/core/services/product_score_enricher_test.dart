import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/constants/score_constants.dart';
import 'package:nutrilens/core/services/hp_score_calculator.dart';
import 'package:nutrilens/core/services/product_score_enricher.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';

void main() {
  late AppDatabase db;
  late ProductScoreEnricher enricher;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    enricher = ProductScoreEnricher(HpScoreCalculator(db));
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'calculates a fresh HP score when a complete product has no score',
    () async {
      const product = ProductEntity(
        barcode: '8690000000001',
        productName: 'Saralle',
        brands: 'Sarelle',
        ingredientsText: 'Findik, seker, kakao, sut tozu',
        nutriments: NutrimentsEntity(
          energyKcal: 540,
          fat: 32,
          saturatedFat: 8,
          carbohydrates: 56,
          sugars: 52,
          proteins: 6,
          salt: 0.2,
        ),
      );

      final enriched = await enricher.ensureFreshScore(product);

      expect(enriched.hpScore, isNotNull);
      expect(enriched.hpScore, isNot(product.hpScore));
      expect(enriched.hpScoreVersion, ScoreConstants.hpScoreAlgorithmVersion);
    },
  );
}
