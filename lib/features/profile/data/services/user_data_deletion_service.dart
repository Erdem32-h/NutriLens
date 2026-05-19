import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/drift/app_database.dart';
import 'account_deletion_service.dart';

abstract interface class RemoteUserDataStore {
  Future<void> deleteRows({
    required String table,
    required String userIdColumn,
    required String userId,
  });

  Future<void> resetUserProfile(String userId);
}

class SupabaseRemoteUserDataStore implements RemoteUserDataStore {
  final SupabaseClient _client;

  const SupabaseRemoteUserDataStore(this._client);

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
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
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
    await _remoteStore.resetUserProfile(userId);
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
