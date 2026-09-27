import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v5.dart' as v5;

void main() {
  test('sema surumu 6', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 6);
    expect(await db.select(db.fastingDays).get(), isEmpty);
  });

  group('v5 -> v6 migration (drift SchemaVerifier)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v5ten v6ya yukseltme SchemaMismatch atmadan tamamlanir', () async {
      final connection = await verifier.startAt(5);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 6);
    });

    test('v5 verisi korunur, fasting_days bos ve yazilabilir gelir', () async {
      final schema = await verifier.schemaAt(5);
      addTearDown(schema.close);

      final oldDb = v5.DatabaseAtV5(schema.newConnection());
      await oldDb
          .into(oldDb.waterLogs)
          .insert(
            v5.WaterLogsCompanion.insert(
              userId: 'guest',
              day: '2026-09-13',
              goalGlasses: 10,
            ),
          );
      await oldDb.close();

      final db = AppDatabase.forTesting(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 6);

      final row = await db.select(db.waterLogs).getSingle();
      expect(row.userId, 'guest');
      expect(row.day, '2026-09-13');

      expect(await db.select(db.fastingDays).get(), isEmpty);
      await db
          .into(db.fastingDays)
          .insert(
            FastingDaysCompanion.insert(userId: 'guest', day: '2027-02-08'),
          );
      expect((await db.select(db.fastingDays).getSingle()).day, '2027-02-08');
    });
  });
}
