import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/core/services/guest_scan_counter.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/session/guest_migration_service.dart';
import 'package:nutrilens/features/history/data/datasources/scan_history_local_datasource.dart';
import 'package:nutrilens/features/meals/data/datasources/meal_local_datasource.dart';
import 'package:nutrilens/features/profile/data/datasources/user_metrics_local_datasource.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGuestScanCounter extends Mock implements GuestScanCounter {}

void main() {
  late AppDatabase db;
  late UserMetricsLocalDataSource metricsDs;
  late GuestMigrationService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    metricsDs = UserMetricsLocalDataSourceImpl(db);
    final counter = _MockGuestScanCounter();
    when(() => counter.reset()).thenAnswer((_) async {});
    service = GuestMigrationService(
      scanDs: ScanHistoryLocalDataSourceImpl(db),
      mealDs: MealLocalDataSourceImpl(db),
      metricsDs: metricsDs,
      supabase: _MockSupabaseClient(),
      counter: counter,
    );
  });

  tearDown(() => db.close());

  test(
    'discard() misafirin olcum verisini de siler — bir sonraki misafir '
    'oturumu baskasinin boy/kilo/yasini devralmamali',
    () async {
      await metricsDs.save(
        UserMetricsEntity(
          userId: kGuestUserId,
          sex: BiologicalSex.female,
          birthYear: 1990,
          heightCm: 165,
          weightKg: 60,
          activity: ActivityLevel.moderate,
          updatedAt: DateTime(2026, 8, 14),
        ),
      );

      await service.discard();

      expect(await metricsDs.get(kGuestUserId), isNull);
    },
  );
}
