import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v3.dart' as v3;

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('sema surumu 4', () {
    expect(db.schemaVersion, 4);
  });

  test('user_metrics tablosu bos baslar ve tek satir tutar', () async {
    expect(await db.select(db.userMetrics).get(), isEmpty);

    await db
        .into(db.userMetrics)
        .insertOnConflictUpdate(
          UserMetricsCompanion.insert(
            userId: 'guest',
            sex: 'female',
            birthYear: 1990,
            heightCm: 165,
            weightKg: 60,
            activityLevel: 'moderate',
            updatedAt: DateTime(2026, 8, 14),
          ),
        );

    final rows = await db.select(db.userMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.targetWeightKg, isNull);
  });

  test('meal_entries.portionGrams nullable ve varsayilan null', () async {
    await db
        .into(db.mealEntries)
        .insert(
          MealEntriesCompanion.insert(
            id: 'm1',
            userId: 'guest',
            mealName: 'Test',
            mealType: 'lunch',
            capturedAt: DateTime(2026, 8, 14),
          ),
        );

    final row = await db.select(db.mealEntries).getSingle();
    expect(row.portionGrams, isNull);
  });

  // Yukarıdaki 3 test taze kurulumu (onCreate → m.createAll()) doğruluyor —
  // gerçek cihazlarda asıl koşan yol olan onUpgrade'in from < 4 bloğunu hiç
  // çalıştırmıyor. Aşağıdaki grup, Drift'in resmi SchemaVerifier'ıyla gerçek
  // bir v3 → v4 yükseltmesini koşturup doğruluyor.
  group('v3 -> v4 migration (drift SchemaVerifier)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      // Bu grup bilerek AppDatabase'i her testte birden fazla kez açıyor
      // (eski şema + yükseltilmiş şema) — Drift'in "multiple databases"
      // yanlış-pozitif uyarısını burada kapatmak güvenli.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v3 semasindan v4e yukseltme SchemaMismatch atmadan tamamlanir',
        () async {
      final connection = await verifier.startAt(3);
      final migratedDb = AppDatabase.forTesting(connection);
      addTearDown(migratedDb.close);

      await verifier.migrateAndValidate(migratedDb, 4);
    });

    test('v3teki meal_entries satiri v4e tasinir; portion_grams null gelir',
        () async {
      final schema = await verifier.schemaAt(3);
      addTearDown(schema.close);

      final oldDb = v3.DatabaseAtV3(schema.newConnection());
      await oldDb.into(oldDb.mealEntries).insert(
            v3.MealEntriesCompanion.insert(
              id: 'v3-oncesi-kayit',
              userId: 'guest',
              mealName: 'Migration Oncesi Ogun',
              mealType: 'lunch',
              capturedAt: DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
            ),
          );
      await oldDb.close();

      final migratedDb = AppDatabase.forTesting(schema.newConnection());
      addTearDown(migratedDb.close);
      await verifier.migrateAndValidate(migratedDb, 4);

      final row = await migratedDb.select(migratedDb.mealEntries).getSingle();
      expect(row.id, 'v3-oncesi-kayit');
      expect(row.mealName, 'Migration Oncesi Ogun');
      expect(row.portionGrams, isNull);
    });
  });
}
