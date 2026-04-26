import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/services/hp_score_calculator.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

void main() {
  late AppDatabase db;
  late HpScoreCalculator calculator;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    calculator = HpScoreCalculator(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'penalizes products with sugar and refined wheat flour even when nutrition is missing',
    () async {
      final result = await calculator.calculateFull(
        additivesTags: const [],
        nutriments: const NutrimentsEntity(),
        ingredientsText: 'İçindekiler: buğday unu, şeker, maya, tuz',
      );

      expect(result.hpScore, lessThan(75));
      expect(result.gaugeLevel, greaterThan(1));
    },
  );
}
