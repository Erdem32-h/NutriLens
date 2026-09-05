import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class UserDataCleaner {
  Future<void> deleteAllUserData(String userId);
  Future<void> deleteLocalUserData(String userId);
}

abstract interface class RemoteAccountDeletionStore {
  Future<void> deleteAccount(String userId);
}

abstract interface class AuthSessionTerminator {
  Future<void> signOut();
}

class AccountDeletionException implements Exception {
  final String message;
  final int? statusCode;

  const AccountDeletionException(this.message, {this.statusCode});

  @override
  String toString() => 'AccountDeletionException($statusCode): $message';
}

class SupabaseRemoteAccountDeletionStore implements RemoteAccountDeletionStore {
  final SupabaseClient _client;

  const SupabaseRemoteAccountDeletionStore(this._client);

  @override
  Future<void> deleteAccount(String userId) async {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw const AccountDeletionException('Not signed in', statusCode: 401);
    }

    try {
      final response = await _client.functions.invoke(
        'delete-account',
        headers: {'Authorization': 'Bearer $token'},
        body: {'user_id': userId},
      );
      if (response.status != 200 ||
          response.data is! Map ||
          response.data['status'] != 'ok') {
        throw AccountDeletionException(
          'Account deletion was not confirmed',
          statusCode: response.status,
        );
      }
    } on AccountDeletionException {
      rethrow;
    } on FunctionException catch (e) {
      throw AccountDeletionException(
        e.details?.toString() ?? e.reasonPhrase ?? 'Account deletion failed',
        statusCode: e.status,
      );
    } catch (e) {
      throw AccountDeletionException(e.toString());
    }
  }
}

class SupabaseAuthSessionTerminator implements AuthSessionTerminator {
  final SupabaseClient _client;

  const SupabaseAuthSessionTerminator(this._client);

  @override
  Future<void> signOut() async {
    // Scope only this device; the server already deleted the account.
    // Supabase clears local state before its best-effort server sign-out.
    await _client.auth.signOut(scope: SignOutScope.local);
  }
}

class AccountDeletionService {
  final UserDataCleaner _userDataCleaner;
  final RemoteAccountDeletionStore _accountStore;
  final AuthSessionTerminator _authSession;
  final SharedPreferences _preferences;
  static const _pendingLocalCleanup = 'account_deletion.pending_local_user';

  const AccountDeletionService({
    required UserDataCleaner userDataCleaner,
    required RemoteAccountDeletionStore accountStore,
    required AuthSessionTerminator authSession,
    required SharedPreferences preferences,
  }) : _userDataCleaner = userDataCleaner,
       _accountStore = accountStore,
       _authSession = authSession,
       _preferences = preferences;

  Future<void> deleteAccount(String userId) async {
    // The server owns remote cleanup. A missing/unavailable endpoint must
    // never erase local data or partially wipe remote tables in the client.
    if (_preferences.getString(_pendingLocalCleanup) != userId) {
      await _accountStore.deleteAccount(userId);
      await _preferences.setString(_pendingLocalCleanup, userId);
    }
    await _userDataCleaner.deleteLocalUserData(userId);
    await _authSession.signOut();
    await _preferences.remove(_pendingLocalCleanup);
  }

  /// A server-confirmed deletion may outlive the session (or the process).
  /// Resume only local work, never send another destructive server request.
  Future<void> resumePendingCleanup() async {
    final userId = _preferences.getString(_pendingLocalCleanup);
    if (userId == null) return;
    await _userDataCleaner.deleteLocalUserData(userId);
    await _preferences.remove(_pendingLocalCleanup);
  }
}
