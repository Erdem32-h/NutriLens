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
import 'tables/meal_entries_table.dart';
import 'tables/user_metrics_table.dart';
import 'tables/water_logs_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FoodProducts,
    Additives,
    Allergens,
    ScanHistory,
    Favorites,
    Blacklist,
    CounterfeitProducts,
    MealEntries,
    UserMetrics,
    WaterLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 5;

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
        if (from < 3) {
          await m.createTable(mealEntries);
        }
        if (from < 4) {
          await m.createTable(userMetrics);
          // meal_entries created at the `from < 3` step above already
          // carries portion_grams, because createTable emits the CURRENT
          // schema. Only a table that genuinely predates v4 needs the ALTER.
          if (from >= 3) {
            await m.addColumn(mealEntries, mealEntries.portionGrams);
          }
        }
        // `to` guard: SchemaVerifier replays older steps with `to` pinned to
        // the version under test (e.g. 3 → 4). Without it, the v3→v4 test
        // would also get this table and fail validation.
        if (from < 5 && to >= 5) {
          await m.createTable(waterLogs);
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
