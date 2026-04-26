import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'tables/food_products_table.dart';
import 'tables/additives_table.dart';
import 'tables/allergens_table.dart';
import 'tables/scan_history_table.dart';
import 'tables/favorites_table.dart';
import 'tables/blacklist_table.dart';
import 'tables/counterfeit_products_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  FoodProducts,
  Additives,
  Allergens,
  ScanHistory,
  Favorites,
  Blacklist,
  CounterfeitProducts,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(foodProducts, foodProducts.hpScoreVersion);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'nutrilens.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
