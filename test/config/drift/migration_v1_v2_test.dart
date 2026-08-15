// Regression test for the v1/v2 -> v4 migration bug fixed on
// feat/kisisel-kalori-hedefi: `Migrator.createTable` emits the CURRENT
// schema, so the `from < 3` step already creates `meal_entries` WITH
// `portion_grams`. The old, unguarded `from < 4` step then tried to
// `ALTER TABLE meal_entries ADD COLUMN portion_grams` a second time,
// throwing `duplicate column name: portion_grams` and rolling back the
// whole migration transaction — bricking any device still on schema v1
// or v2 (both existed in production before schema v3 shipped).
//
// `migration_v4_test.dart` only exercises `startAt(3)` via drift's
// SchemaVerifier, which is why this never caught the bug: v1 and v2
// databases never went through `from < 3` at all in that test.
//
// A real drift SchemaVerifier snapshot (`drift_schemas/drift_schema_v1.json`
// / `_v2.json`) would need `dart run drift_dev schema dump` run against the
// v1/v2-era `AppDatabase` source, i.e. the actual old table definitions as
// they existed before schema v3. Reconstructing that source is possible
// without switching branches (git history can be read via `git show`), but
// generating the snapshot means temporarily materializing those old table
// files back into `lib/` so drift_dev's analyzer step can see them, then
// removing them again — a broad, riskier change to make on a "fix findings,
// don't touch anything else" pass. Given the explicit hand-rolled fallback
// this task authorizes, we instead reconstruct the pre-v2 SQLite DDL by hand
// (verified against `git show 28b58ff:lib/config/drift/tables/*.dart`, the
// v1 commit) and drive a real `AppDatabase.forTesting` migration over it.
// This still exercises the exact code path that bricked real devices: the
// `MigrationStrategy.onUpgrade` callback in `app_database.dart`, run by real
// drift/sqlite3, starting from `PRAGMA user_version = 1` (or 2).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

// v1-era `food_products` — no `hp_score_version` column yet.
// Source: git show 28b58ff:lib/config/drift/tables/food_products_table.dart
const _v1FoodProductsSql = '''
CREATE TABLE food_products (
  barcode TEXT NOT NULL,
  product_name TEXT NULL,
  brands TEXT NULL,
  image_url TEXT NULL,
  ingredients_text TEXT NULL,
  allergens_tags TEXT NOT NULL DEFAULT '[]',
  additives_tags TEXT NOT NULL DEFAULT '[]',
  nova_group INTEGER NULL,
  nutriscore_grade TEXT NULL,
  nutriments TEXT NOT NULL DEFAULT '{}',
  categories_tags TEXT NOT NULL DEFAULT '[]',
  countries_tags TEXT NOT NULL DEFAULT '[]',
  hp_score REAL NULL,
  hp_chemical_load REAL NULL,
  hp_risk_factor REAL NULL,
  hp_nutri_factor REAL NULL,
  cached_at INTEGER NOT NULL,
  PRIMARY KEY (barcode)
);
''';

// v2-era `food_products` — `hp_score_version` already added by the v1->v2
// migration that ran on this (hypothetical previous) app launch.
// Source: git show f41e1ce:lib/config/drift/tables/food_products_table.dart
const _v2FoodProductsSql = '''
CREATE TABLE food_products (
  barcode TEXT NOT NULL,
  product_name TEXT NULL,
  brands TEXT NULL,
  image_url TEXT NULL,
  ingredients_text TEXT NULL,
  allergens_tags TEXT NOT NULL DEFAULT '[]',
  additives_tags TEXT NOT NULL DEFAULT '[]',
  nova_group INTEGER NULL,
  nutriscore_grade TEXT NULL,
  nutriments TEXT NOT NULL DEFAULT '{}',
  categories_tags TEXT NOT NULL DEFAULT '[]',
  countries_tags TEXT NOT NULL DEFAULT '[]',
  hp_score REAL NULL,
  hp_chemical_load REAL NULL,
  hp_risk_factor REAL NULL,
  hp_nutri_factor REAL NULL,
  hp_score_version INTEGER NOT NULL DEFAULT 0,
  cached_at INTEGER NOT NULL,
  PRIMARY KEY (barcode)
);
''';

// The rest of the v1 tables. No `onUpgrade` step ever touches these, but we
// create them anyway so the fixture is a faithful v1 device database rather
// than a convenient subset that happens to dodge the bug.
const _v1OtherTablesSql = '''
CREATE TABLE additives (
  id TEXT NOT NULL,
  e_number TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_tr TEXT NULL,
  category TEXT NOT NULL,
  risk_level INTEGER NOT NULL,
  risk_label TEXT NOT NULL,
  description_en TEXT NULL,
  description_tr TEXT NULL,
  efsa_status TEXT NULL,
  turkish_codex_status TEXT NULL,
  max_daily_intake TEXT NULL,
  source TEXT NULL,
  is_vegan INTEGER NOT NULL DEFAULT 1,
  is_vegetarian INTEGER NOT NULL DEFAULT 1,
  is_halal INTEGER NOT NULL DEFAULT 1,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE allergens (
  id TEXT NOT NULL,
  name_en TEXT NOT NULL,
  name_tr TEXT NOT NULL,
  category TEXT NULL,
  icon_name TEXT NULL,
  severity_note TEXT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE blacklist (
  id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  barcode TEXT NOT NULL,
  reason TEXT NULL,
  added_at INTEGER NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (user_id, barcode)
);
CREATE TABLE counterfeit_products (
  id TEXT NOT NULL,
  brand_name TEXT NOT NULL,
  product_name TEXT NOT NULL,
  category TEXT NULL,
  violation_type TEXT NOT NULL,
  violation_detail TEXT NULL,
  province TEXT NULL,
  detection_date INTEGER NULL,
  barcode TEXT NULL,
  source_url TEXT NULL,
  synced_at INTEGER NOT NULL,
  PRIMARY KEY (id)
);
CREATE TABLE favorites (
  id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  barcode TEXT NOT NULL,
  added_at INTEGER NOT NULL,
  PRIMARY KEY (id),
  UNIQUE (user_id, barcode)
);
CREATE TABLE scan_history (
  id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  barcode TEXT NOT NULL,
  scanned_at INTEGER NOT NULL,
  hp_score_at_scan REAL NULL,
  compatibility_result TEXT NOT NULL DEFAULT '{}',
  PRIMARY KEY (id)
);
''';

/// Opens a raw sqlite3 database shaped like a real device sitting at schema
/// [version] (1 or 2), wraps it in a drift [NativeDatabase], hands it to
/// [AppDatabase.forTesting] and forces the pending migration to run — the
/// same thing that happens the moment a user on an old build opens the app
/// after installing this branch.
Future<AppDatabase> _openAndMigrateFrom(int version) async {
  assert(version == 1 || version == 2);

  final raw = sqlite3.sqlite3.openInMemory();
  raw.execute(version >= 2 ? _v2FoodProductsSql : _v1FoodProductsSql);
  raw.execute(_v1OtherTablesSql);
  raw.userVersion = version;

  final db = AppDatabase.forTesting(NativeDatabase.opened(raw));

  // Any query forces drift to check `PRAGMA user_version` and run the
  // pending `onUpgrade` migration before answering.
  await db.customSelect('SELECT 1').get();

  return db;
}

void main() {
  test(
    'v1 -> v4 migration completes without throwing and does not '
    'double-add portion_grams',
    () async {
      final db = await _openAndMigrateFrom(1);
      addTearDown(db.close);

      final portionGramsColumns = await db
          .customSelect(
            "SELECT name FROM pragma_table_info('meal_entries') "
            "WHERE name = 'portion_grams'",
          )
          .get();
      expect(portionGramsColumns, hasLength(1));

      final hpScoreVersionColumns = await db
          .customSelect(
            "SELECT name FROM pragma_table_info('food_products') "
            "WHERE name = 'hp_score_version'",
          )
          .get();
      expect(hpScoreVersionColumns, hasLength(1));
    },
  );

  test(
    'v2 -> v4 migration completes without throwing and does not '
    'double-add portion_grams',
    () async {
      final db = await _openAndMigrateFrom(2);
      addTearDown(db.close);

      final portionGramsColumns = await db
          .customSelect(
            "SELECT name FROM pragma_table_info('meal_entries') "
            "WHERE name = 'portion_grams'",
          )
          .get();
      expect(portionGramsColumns, hasLength(1));
    },
  );
}
