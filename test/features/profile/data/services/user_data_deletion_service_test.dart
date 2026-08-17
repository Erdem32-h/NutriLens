import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/features/profile/data/services/user_data_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late _RecordingRemoteUserDataStore remote;
  late UserDataDeletionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'health_filters_allergens': ['milk'],
      'health_filters_diets': ['vegan'],
      'health_filters_oils': ['palm'],
      'health_filters_chemicals': ['msg'],
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    remote = _RecordingRemoteUserDataStore();
    service = UserDataDeletionService(
      db: db,
      remoteStore: remote,
      preferences: prefs,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('deletes only user-scoped data and keeps product records', () async {
    await db
        .into(db.scanHistory)
        .insert(
          ScanHistoryCompanion.insert(
            id: 'scan-user-1',
            userId: 'user-1',
            barcode: '8691',
          ),
        );
    await db
        .into(db.scanHistory)
        .insert(
          ScanHistoryCompanion.insert(
            id: 'scan-user-2',
            userId: 'user-2',
            barcode: '8692',
          ),
        );
    await db
        .into(db.favorites)
        .insert(
          FavoritesCompanion.insert(
            id: 'fav-user-1',
            userId: 'user-1',
            barcode: '8691',
          ),
        );
    await db
        .into(db.blacklist)
        .insert(
          BlacklistCompanion.insert(
            id: 'block-user-1',
            userId: 'user-1',
            barcode: '8693',
          ),
        );
    await db
        .into(db.mealEntries)
        .insert(
          MealEntriesCompanion.insert(
            id: 'meal-user-1',
            userId: 'user-1',
            mealName: 'Kahvaltı',
            mealType: 'breakfast',
            capturedAt: DateTime(2026, 5, 10, 8),
          ),
        );
    await db
        .into(db.foodProducts)
        .insert(
          FoodProductsCompanion.insert(
            barcode: '8691',
            productName: const Value('Kullanıcı Eklediği Ürün'),
          ),
        );

    await service.deleteAllUserData('user-1');

    expect(await db.select(db.scanHistory).get(), hasLength(1));
    expect((await db.select(db.scanHistory).get()).single.userId, 'user-2');
    expect(await db.select(db.favorites).get(), isEmpty);
    expect(await db.select(db.blacklist).get(), isEmpty);
    expect(await db.select(db.mealEntries).get(), isEmpty);
    expect(await db.select(db.foodProducts).get(), hasLength(1));
    expect(prefs.getStringList('health_filters_allergens'), isNull);
  });

  test(
    'clears remote user tables without deleting community products',
    () async {
      await service.deleteAllUserData('user-1');

      expect(remote.deletedTables, [
        'scan_history:user_id:user-1',
        'favorites:user_id:user-1',
        'blacklist:user_id:user-1',
        'daily_scans:user_id:user-1',
        'meal_entries:user_id:user-1',
      ]);
      expect(remote.resetProfiles, ['user-1']);
      expect(
        remote.deletedTables.any(
          (entry) => entry.startsWith('community_products'),
        ),
        isFalse,
      );
    },
  );

  test('empties the user photo folder in cloud storage', () async {
    await service.deleteAllUserData('user-1');

    expect(remote.photoFolders, ['user-1']);
  });

  test('a storage failure fails the whole deletion instead of passing', () async {
    // The user is told their data is gone; if the photos survived, that claim
    // is false. Better a visible error and a retry than a silent half-deletion.
    remote.failPhotoDeletion = true;

    await expectLater(service.deleteAllUserData('user-1'), throwsException);
  });

  group('SupabaseRemoteUserDataStore.clearedProfileColumns', () {
    // Compliance test: the body measurements are declared as health data in
    // both store privacy forms, so a deletion request has to reach them.
    const bodyColumns = [
      'sex',
      'birth_year',
      'height_cm',
      'weight_kg',
      'target_weight_kg',
      'activity_level',
    ];

    for (final column in bodyColumns) {
      test('clears $column', () {
        expect(
          SupabaseRemoteUserDataStore.clearedProfileColumns,
          containsPair(column, isNull),
        );
      });
    }
  });
}

class _RecordingRemoteUserDataStore implements RemoteUserDataStore {
  final deletedTables = <String>[];
  final resetProfiles = <String>[];
  final photoFolders = <String>[];
  bool failPhotoDeletion = false;

  @override
  Future<void> deleteRows({
    required String table,
    required String userIdColumn,
    required String userId,
  }) async {
    deletedTables.add('$table:$userIdColumn:$userId');
  }

  @override
  Future<void> resetUserProfile(String userId) async {
    resetProfiles.add(userId);
  }

  @override
  Future<void> deleteMealPhotos(String userId) async {
    if (failPhotoDeletion) throw Exception('storage unavailable');
    photoFolders.add(userId);
  }
}
