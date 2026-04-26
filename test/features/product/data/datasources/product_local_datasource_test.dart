import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/constants/score_constants.dart';
import 'package:nutrilens/features/product/data/datasources/product_local_datasource.dart';
import 'package:nutrilens/features/product/domain/entities/product_entity.dart';

void main() {
  late AppDatabase db;
  late ProductLocalDataSourceImpl dataSource;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dataSource = ProductLocalDataSourceImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('treats cached product as stale when score algorithm version is old',
      () async {
    await dataSource.cacheProduct(
      const ProductEntity(
        barcode: '8690000000001',
        productName: 'Old Score Product',
        hpScore: 90,
        hpScoreVersion: ScoreConstants.hpScoreAlgorithmVersion - 1,
      ),
    );

    expect(await dataSource.isStale('8690000000001'), isTrue);
  });

  test('keeps freshly cached product current when score version matches',
      () async {
    await dataSource.cacheProduct(
      const ProductEntity(
        barcode: '8690000000001',
        productName: 'Current Score Product',
        hpScore: 90,
      ),
    );

    expect(await dataSource.isStale('8690000000001'), isFalse);
  });
}
