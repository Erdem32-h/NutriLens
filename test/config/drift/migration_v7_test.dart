import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v6.dart' as v6;

void main() {
  test('sema surumu 7', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 7);
    expect(await db.select(db.fastingSessions).get(), isEmpty);
  });

  group('v6 -> v7 migration (drift SchemaVerifier)', () {
    late SchemaVerifier verifier;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      verifier = SchemaVerifier(GeneratedHelper());
    });

    test('v6dan v7ye yukseltme SchemaMismatch atmadan tamamlanir', () async {
      final connection = await verifier.startAt(6);
      final db = AppDatabase.forTesting(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(db, 7);
    });

    test(
      'v6 verisi korunur, fasting_sessions bos ve yazilabilir gelir',
      () async {
        final schema = await verifier.schemaAt(6);
        addTearDown(schema.close);

        final oldDb = v6.DatabaseAtV6(schema.newConnection());
        await oldDb
            .into(oldDb.fastingDays)
            .insert(
              v6.FastingDaysCompanion.insert(
                userId: 'guest',
                day: '2027-02-08',
              ),
            );
        await oldDb.close();

        final db = AppDatabase.forTesting(schema.newConnection());
        addTearDown(db.close);
        await verifier.migrateAndValidate(db, 7);

        final row = await db.select(db.fastingDays).getSingle();
        expect(row.userId, 'guest');
        expect(row.day, '2027-02-08');

        expect(await db.select(db.fastingSessions).get(), isEmpty);
        await db
            .into(db.fastingSessions)
            .insert(
              FastingSessionsCompanion.insert(
                id: 's1',
                userId: 'guest',
                startedAt: DateTime.utc(2027, 2, 8),
                targetMinutes: 960,
              ),
            );
        expect(
          (await db.select(db.fastingSessions).getSingle()).id,
          's1',
        );
      },
    );
  });
}
