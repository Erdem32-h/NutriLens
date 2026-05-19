import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/profile/data/services/account_deletion_service.dart';

void main() {
  test('cleans user data before deleting account and signing out', () async {
    final events = <String>[];
    final userData = _RecordingUserDataCleaner(events);
    final accountStore = _RecordingRemoteAccountStore(events);
    final auth = _RecordingAuthSession(events);
    final service = AccountDeletionService(
      userDataCleaner: userData,
      accountStore: accountStore,
      authSession: auth,
    );

    await service.deleteAccount('user-1');

    expect(events, ['clean:user-1', 'delete-account:user-1', 'sign-out']);
  });

  test('does not sign out when remote account deletion fails', () async {
    final events = <String>[];
    final service = AccountDeletionService(
      userDataCleaner: _RecordingUserDataCleaner(events),
      accountStore: _FailingRemoteAccountStore(events),
      authSession: _RecordingAuthSession(events),
    );

    await expectLater(
      service.deleteAccount('user-1'),
      throwsA(isA<AccountDeletionException>()),
    );

    expect(events, ['clean:user-1', 'delete-account:user-1']);
  });
}

class _RecordingUserDataCleaner implements UserDataCleaner {
  final List<String> events;

  const _RecordingUserDataCleaner(this.events);

  @override
  Future<void> deleteAllUserData(String userId) async {
    events.add('clean:$userId');
  }
}

class _RecordingRemoteAccountStore implements RemoteAccountDeletionStore {
  final List<String> events;

  const _RecordingRemoteAccountStore(this.events);

  @override
  Future<void> deleteAccount(String userId) async {
    events.add('delete-account:$userId');
  }
}

class _FailingRemoteAccountStore implements RemoteAccountDeletionStore {
  final List<String> events;

  const _FailingRemoteAccountStore(this.events);

  @override
  Future<void> deleteAccount(String userId) async {
    events.add('delete-account:$userId');
    throw const AccountDeletionException('failed');
  }
}

class _RecordingAuthSession implements AuthSessionTerminator {
  final List<String> events;

  const _RecordingAuthSession(this.events);

  @override
  Future<void> signOut() async {
    events.add('sign-out');
  }
}
