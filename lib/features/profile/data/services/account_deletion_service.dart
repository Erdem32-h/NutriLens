import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

abstract interface class UserDataCleaner {
  Future<void> deleteAllUserData(String userId);
  Future<void> deleteLocalUserData(String userId);
}

abstract interface class RemoteAccountDeletionStore {
  Future<void> deleteAccount(String userId);
  Future<bool> isDeletionCompleted(String userId);
}

abstract interface class AuthSessionTerminator {
  Future<void> signOutIfCurrent(String userId);
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
  final SharedPreferences _preferences;

  const SupabaseRemoteAccountDeletionStore(this._client, this._preferences);

  @override
  Future<bool> isDeletionCompleted(String userId) async {
    final requestToken = _preferences.getString(
      'account_deletion.request.$userId',
    );
    if (requestToken == null) return false;
    final response = await _client.functions.invoke(
      'delete-account',
      body: {
        'user_id': userId,
        'request_token': requestToken,
        'receipt_only': true,
      },
    );
    return response.status == 200 &&
        response.data is Map &&
        response.data['status'] == 'ok';
  }

  @override
  Future<void> deleteAccount(String userId) async {
    final token = _client.auth.currentSession?.accessToken;
    final receiptKey = 'account_deletion.request.$userId';
    var requestToken = _preferences.getString(receiptKey);
    if ((token == null || token.isEmpty) && requestToken == null) {
      throw const AccountDeletionException('Not signed in', statusCode: 401);
    }
    if (requestToken == null) {
      requestToken = const Uuid().v4();
      if (!await _preferences.setString(receiptKey, requestToken)) {
        throw const AccountDeletionException(
          'Could not persist deletion request',
        );
      }
    }

    try {
      final response = await _client.functions.invoke(
        'delete-account',
        // Without a session FunctionsClient uses the anon bearer. Only a
        // matching completed receipt can succeed without Auth.getUser.
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
        body: {'user_id': userId, 'request_token': requestToken},
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
  Future<void> signOutIfCurrent(String userId) async {
    if (_client.auth.currentUser?.id != userId) return;
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
    await _authSession.signOutIfCurrent(userId);
    await _preferences.remove(_pendingLocalCleanup);
    await _preferences.remove('account_deletion.request.$userId');
  }

  /// A server-confirmed deletion may outlive the session (or the process).
  /// Resume only local work, never send another destructive server request.
  Future<void> resumePendingCleanup() async {
    final confirmed = _preferences.getString(_pendingLocalCleanup);
    final requests = _preferences
        .getKeys()
        .where((key) => key.startsWith('account_deletion.request.'))
        .map((key) => key.substring('account_deletion.request.'.length))
        .toSet();
    if (confirmed != null) requests.add(confirmed);
    for (final userId in requests) {
      // Status checks cannot initiate or resume destructive server work.
      if (userId != confirmed &&
          !await _accountStore.isDeletionCompleted(userId)) {
        continue;
      }
      await _userDataCleaner.deleteLocalUserData(userId);
      await _authSession.signOutIfCurrent(userId);
      if (_preferences.getString(_pendingLocalCleanup) == userId) {
        await _preferences.remove(_pendingLocalCleanup);
      }
      await _preferences.remove('account_deletion.request.$userId');
    }
  }
}
