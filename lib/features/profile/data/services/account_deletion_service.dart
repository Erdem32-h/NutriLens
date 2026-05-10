import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class UserDataCleaner {
  Future<void> deleteAllUserData(String userId);
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
      await _client.functions.invoke(
        'delete-account',
        headers: {'Authorization': 'Bearer $token'},
        body: {'user_id': userId},
      );
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
    await _client.auth.signOut();
  }
}

class AccountDeletionService {
  final UserDataCleaner _userDataCleaner;
  final RemoteAccountDeletionStore _accountStore;
  final AuthSessionTerminator _authSession;

  const AccountDeletionService({
    required UserDataCleaner userDataCleaner,
    required RemoteAccountDeletionStore accountStore,
    required AuthSessionTerminator authSession,
  }) : _userDataCleaner = userDataCleaner,
       _accountStore = accountStore,
       _authSession = authSession;

  Future<void> deleteAccount(String userId) async {
    await _userDataCleaner.deleteAllUserData(userId);
    await _accountStore.deleteAccount(userId);
    await _authSession.signOut();
  }
}
