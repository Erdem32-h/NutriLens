import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/profile/data/services/account_deletion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockClient extends Mock implements SupabaseClient {}

class _MockAuth extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

class _MockSession extends Mock implements Session {}

class _MockFunctions extends Mock implements FunctionsClient {}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test(
    'remote retry reuses persisted capability after lost success response',
    () async {
      final client = _MockClient();
      final auth = _MockAuth();
      final session = _MockSession();
      final functions = _MockFunctions();
      when(() => client.auth).thenReturn(auth);
      when(() => client.functions).thenReturn(functions);
      when(() => auth.currentSession).thenReturn(session);
      when(() => session.accessToken).thenReturn('old-access-token');
      final sent = <Map<String, dynamic>>[];
      when(
        () => functions.invoke(
          'delete-account',
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        sent.add(
          Map<String, dynamic>.from(invocation.namedArguments[#body] as Map),
        );
        if (sent.length == 1) throw Exception('response lost');
        return FunctionResponse(status: 200, data: {'status': 'ok'});
      });
      final store = SupabaseRemoteAccountDeletionStore(client, prefs);
      await expectLater(
        store.deleteAccount('user-1'),
        throwsA(isA<AccountDeletionException>()),
      );
      final saved = prefs.getString('account_deletion.request.user-1');
      expect(saved, isNotNull);
      when(() => auth.currentSession).thenReturn(null);
      await store.deleteAccount('user-1');
      expect(sent[0]['request_token'], saved);
      expect(sent[1]['request_token'], saved);
      expect(sent.every((body) => body['user_id'] == 'user-1'), isTrue);
    },
  );

  test(
    'receipt recovery sends status-only request, never a destructive retry',
    () async {
      final client = _MockClient();
      final functions = _MockFunctions();
      when(() => client.functions).thenReturn(functions);
      await prefs.setString(
        'account_deletion.request.user-1',
        'persisted-capability',
      );
      when(
        () => functions.invoke('delete-account', body: any(named: 'body')),
      ).thenAnswer((invocation) async {
        expect(invocation.namedArguments[#body], {
          'user_id': 'user-1',
          'request_token': 'persisted-capability',
          'receipt_only': true,
        });
        return FunctionResponse(status: 200, data: {'status': 'unconfirmed'});
      });
      expect(
        await SupabaseRemoteAccountDeletionStore(
          client,
          prefs,
        ).isDeletionCompleted('user-1'),
        isFalse,
      );
    },
  );

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

  test('lost response is recovered with a read-only receipt check', () async {
    final events = <String>[];
    await prefs.setString(
      'account_deletion.request.user-1',
      'saved-capability',
    );
    final service = AccountDeletionService(
      userDataCleaner: _RecordingUserDataCleaner(events),
      accountStore: _RecordingRemoteAccountStore(events),
      authSession: _RecordingAuthSession(events),
      preferences: prefs,
    );
    await service.resumePendingCleanup();
    expect(events, ['local:user-1', 'sign-out']);
    expect(prefs.getKeys(), isEmpty);
  });

  test('unconfirmed request never clears local data on startup', () async {
    final events = <String>[];
    await prefs.setString(
      'account_deletion.request.user-1',
      'saved-capability',
    );
    final service = AccountDeletionService(
      userDataCleaner: _RecordingUserDataCleaner(events),
      accountStore: _FailingRemoteAccountStore(events),
      authSession: _RecordingAuthSession(events),
      preferences: prefs,
    );
    await service.resumePendingCleanup();
    expect(events, isEmpty);
    expect(prefs.getString('account_deletion.request.user-1'), isNotNull);
  });

  for (final current in ['user-1', 'user-2', null]) {
    test('cleanup only signs out deleted account (current=$current)', () async {
      final client = _MockClient();
      final auth = _MockAuth();
      final user = _MockUser();
      when(() => client.auth).thenReturn(auth);
      when(() => user.id).thenReturn(current ?? 'unused');
      when(() => auth.currentUser).thenReturn(current == null ? null : user);
      when(
        () => auth.signOut(scope: SignOutScope.local),
      ).thenAnswer((_) async {});
      await SupabaseAuthSessionTerminator(client).signOutIfCurrent('user-1');
      if (current == 'user-1') {
        verify(() => auth.signOut(scope: SignOutScope.local)).called(1);
      } else {
        verifyNever(() => auth.signOut(scope: SignOutScope.local));
      }
    });
  }

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
      expect(events, ['local:user-1', 'sign-out']);
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
  Future<bool> isDeletionCompleted(String userId) async => true;

  @override
  Future<void> deleteAccount(String userId) async {
    events.add('delete-account:$userId');
  }
}

class _FailingRemoteAccountStore implements RemoteAccountDeletionStore {
  final List<String> events;

  const _FailingRemoteAccountStore(this.events);

  @override
  Future<bool> isDeletionCompleted(String userId) async => false;

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
  Future<void> signOutIfCurrent(String userId) async {
    events.add('sign-out');
  }
}
