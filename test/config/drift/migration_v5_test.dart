import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v4.dart' as v4;

void main() {
  test('sema surumu 5', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 5);
    expect(await db.select(db.waterLogs).get(), isEmpty);
  });

  group('v4 -> v5 migration (drift SchemaVerifier)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v4ten v5e yukseltme SchemaMismatch atmadan tamamlanir', () async {
      final connection = await verifier.startAt(4);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 5);
    });

    test('v4 verisi korunur, water_logs bos ve yazilabilir gelir', () async {
      final schema = await verifier.schemaAt(4);
      addTearDown(schema.close);

      final oldDb = v4.DatabaseAtV4(schema.newConnection());
      await oldDb
          .into(oldDb.userMetrics)
          .insert(
            v4.UserMetricsCompanion.insert(
              userId: 'guest',
              sex: 'female',
              birthYear: 1990,
              heightCm: 165,
              weightKg: 60,
              activityLevel: 'moderate',
              updatedAt: DateTime(2026, 9, 1).millisecondsSinceEpoch ~/ 1000,
            ),
          );
      await oldDb.close();

      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 5);

      expect((await db.select(db.userMetrics).get()).single.userId, 'guest');
      await db
          .into(db.waterLogs)
          .insert(
            WaterLogsCompanion.insert(
              userId: 'guest',
              day: '2026-09-13',
              goalGlasses: 10,
            ),
          );
      final row = await db.select(db.waterLogs).getSingle();
      expect(row.glasses, 0);
      expect(row.lastGlassAt, isNull);
    });
  });
}
