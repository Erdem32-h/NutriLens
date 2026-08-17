import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/drift/app_database.dart';
import '../../../meals/data/datasources/meal_remote_datasource.dart';
import 'account_deletion_service.dart';

abstract interface class RemoteUserDataStore {
  Future<void> deleteRows({
    required String table,
    required String userIdColumn,
    required String userId,
  });

  Future<void> resetUserProfile(String userId);

  /// Empty the user's folder in the meal-photo bucket.
  ///
  /// Storage objects are not rows: deleting the auth user cascades through
  /// every table but leaves uploaded files untouched, so this has to be an
  /// explicit step in both the "delete my data" and "delete my account" paths.
  Future<void> deleteMealPhotos(String userId);
}

class SupabaseRemoteUserDataStore implements RemoteUserDataStore {
  final SupabaseClient _client;

  const SupabaseRemoteUserDataStore(this._client);

  /// Everything [resetUserProfile] wipes, minus the `updated_at` stamp.
  ///
  /// Exposed as data so a test can assert the body-measurement columns are in
  /// here. They arrived with the personal calorie target and were missed by the
  /// first version of this reset, which meant "delete all my data" left the
  /// user's height, weight and birth year on the server.
  static const clearedProfileColumns = <String, Object?>{
    'selected_allergens': <String>[],
    'diet_vegan': false,
    'diet_vegetarian': false,
    'diet_gluten_free': false,
    'diet_halal': false,
    'filter_palm_oil': false,
    'filter_canola_oil': false,
    'filter_cotton_oil': false,
    'filter_soy_oil': false,
    'filter_aspartame': false,
    'filter_msg': false,
    'filter_corn_syrup': false,
    // Body measurements behind the personal calorie target. Health data — the
    // App Store and Play declarations both name it, so deletion must reach it.
    'sex': null,
    'birth_year': null,
    'height_cm': null,
    'weight_kg': null,
    'target_weight_kg': null,
    'activity_level': null,
  };

  @override
  Future<void> deleteRows({
    required String table,
    required String userIdColumn,
    required String userId,
  }) async {
    await _client.from(table).delete().eq(userIdColumn, userId);
  }

  @override
  Future<void> resetUserProfile(String userId) async {
    await _client
        .from('user_profiles')
        .update({
          ...clearedProfileColumns,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  @override
  Future<void> deleteMealPhotos(String userId) async {
    final objects = await _client.storage
        .from(MealRemoteDataSource.bucket)
        .list(path: userId);
    if (objects.isEmpty) return;
    await _client.storage
        .from(MealRemoteDataSource.bucket)
        .remove([for (final object in objects) '$userId/${object.name}']);
  }
}

class UserDataDeletionService implements UserDataCleaner {
  static const _healthFilterKeys = [
    'health_filters_allergens',
    'health_filters_diets',
    'health_filters_oils',
    'health_filters_chemicals',
  ];

  final AppDatabase _db;
  final RemoteUserDataStore _remoteStore;
  final SharedPreferences _preferences;

  const UserDataDeletionService({
    required AppDatabase db,
    required RemoteUserDataStore remoteStore,
    required SharedPreferences preferences,
  }) : _db = db,
       _remoteStore = remoteStore,
       _preferences = preferences;

  @override
  Future<void> deleteAllUserData(String userId) async {
    await _deleteRemoteUserData(userId);
    await _deleteLocalUserData(userId);
    await _clearLocalProfilePreferences();
  }

  Future<void> _deleteRemoteUserData(String userId) async {
    await _remoteStore.deleteRows(
      table: 'scan_history',
      userIdColumn: 'user_id',
      userId: userId,
    );
    await _remoteStore.deleteRows(
      table: 'favorites',
      userIdColumn: 'user_id',
      userId: userId,
    );
    await _remoteStore.deleteRows(
      table: 'blacklist',
      userIdColumn: 'user_id',
      userId: userId,
    );
    await _remoteStore.deleteRows(
      table: 'daily_scans',
      userIdColumn: 'user_id',
      userId: userId,
    );
    // Cloud meals are premium-only, but the row survives losing premium — so
    // this runs for everyone, not just current subscribers.
    await _remoteStore.deleteRows(
      table: 'meal_entries',
      userIdColumn: 'user_id',
      userId: userId,
    );
    await _remoteStore.resetUserProfile(userId);
    // Last, and allowed to throw: a failure here surfaces as "deletion failed"
    // and the user retries. Every step above is idempotent, so a retry is safe.
    // Swallowing it would leave photos on the server while telling the user
    // their data is gone.
    await _remoteStore.deleteMealPhotos(userId);
  }

  Future<void> _deleteLocalUserData(String userId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.scanHistory,
      )..where((table) => table.userId.equals(userId))).go();
      await (_db.delete(
        _db.favorites,
      )..where((table) => table.userId.equals(userId))).go();
      await (_db.delete(
        _db.blacklist,
      )..where((table) => table.userId.equals(userId))).go();
      await (_db.delete(
        _db.mealEntries,
      )..where((table) => table.userId.equals(userId))).go();
    });
  }

  Future<void> _clearLocalProfilePreferences() async {
    for (final key in _healthFilterKeys) {
      await _preferences.remove(key);
    }
  }
}
