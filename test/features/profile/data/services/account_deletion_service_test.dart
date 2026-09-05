import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/profile/data/services/account_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('deletes remote account before local cleanup and sign out', () async {
    final events = <String>[];
    final userData = _RecordingUserDataCleaner(events);
    final accountStore = _RecordingRemoteAccountStore(events);
    final auth = _RecordingAuthSession(events);
    final service = AccountDeletionService(
      userDataCleaner: userData,
      accountStore: accountStore,
      authSession: auth,
      preferences: prefs,
    );

    await service.deleteAccount('user-1');

    expect(events, ['delete-account:user-1', 'local:user-1', 'sign-out']);
  });

  test('does not sign out when remote account deletion fails', () async {
    final events = <String>[];
    final service = AccountDeletionService(
      userDataCleaner: _RecordingUserDataCleaner(events),
      accountStore: _FailingRemoteAccountStore(events),
      authSession: _RecordingAuthSession(events),
      preferences: prefs,
    );

    await expectLater(
      service.deleteAccount('user-1'),
      throwsA(isA<AccountDeletionException>()),
    );

    expect(events, ['delete-account:user-1']);
  });

  test(
    'pending local cleanup resumes after restart without remote deletion',
    () async {
      final events = <String>[];
      await prefs.setString('account_deletion.pending_local_user', 'user-1');
      final service = AccountDeletionService(
        userDataCleaner: _RecordingUserDataCleaner(events),
        accountStore: _FailingRemoteAccountStore(events),
        authSession: _RecordingAuthSession(events),
        preferences: prefs,
      );
      await service.resumePendingCleanup();
      expect(events, ['local:user-1']);
      expect(prefs.getString('account_deletion.pending_local_user'), isNull);
    },
  );

  test(
    'retries local cleanup without deleting the remote account again',
    () async {
      final events = <String>[];
      final cleaner = _RecordingUserDataCleaner(events)..failLocal = true;
      AccountDeletionService createService() => AccountDeletionService(
        userDataCleaner: cleaner,
        accountStore: _RecordingRemoteAccountStore(events),
        authSession: _RecordingAuthSession(events),
        preferences: prefs,
      );
      await expectLater(
        createService().deleteAccount('user-1'),
        throwsStateError,
      );
      cleaner.failLocal = false;
      await createService().deleteAccount('user-1');
      expect(events, [
        'delete-account:user-1',
        'local:user-1',
        'local:user-1',
        'sign-out',
      ]);
      expect(prefs.getString('account_deletion.pending_local_user'), isNull);
    },
  );
}

class _RecordingUserDataCleaner implements UserDataCleaner {
  final List<String> events;

  _RecordingUserDataCleaner(this.events);
  bool failLocal = false;

  @override
  Future<void> deleteAllUserData(String userId) async {
    events.add('clean:$userId');
  }

  @override
  Future<void> deleteLocalUserData(String userId) async {
    events.add('local:$userId');
    if (failLocal) throw StateError('disk unavailable');
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
