import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/services/notification_service.dart';
import 'package:nutrilens/core/services/subscription_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/features/auth/domain/entities/user_entity.dart';
import 'package:nutrilens/features/auth/domain/repositories/auth_repository.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockNotificationService extends Mock implements NotificationService {}

class _FakeAppSessionController implements AppSessionController {
  int exitCalls = 0;

  @override
  Future<void> exitGuestMode() async => exitCalls++;

  @override
  Future<void> enterGuestMode() async {}

  @override
  Future<void> completeOnboarding() async {}
}

void main() {
  test('currentUserProvider follows auth state changes', () async {
    final authState = StreamController<UserEntity?>();
    final repository = MockAuthRepository();
    const oldUser = UserEntity(id: 'old-user', email: 'old@example.com');
    const newUser = UserEntity(id: 'new-user', email: 'new@example.com');

    when(
      () => repository.authStateChanges(),
    ).thenAnswer((_) => authState.stream);
    when(() => repository.currentUser).thenReturn(oldUser);

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    addTearDown(authState.close);

    expect(container.read(currentUserProvider), oldUser);

    final emitted = Completer<UserEntity?>();
    container.listen<AsyncValue<UserEntity?>>(authStateProvider, (_, next) {
      next.whenData((user) {
        if (!emitted.isCompleted) emitted.complete(user);
      });
    }, fireImmediately: true);
    await Future<void>.delayed(Duration.zero);
    authState.add(newUser);
    await expectLater(emitted.future, completion(newUser));

    expect(container.read(currentUserProvider), newUser);
  });

  test('auth data source uses the overridden Supabase client provider', () {
    final container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(MockSupabaseClient()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(authRemoteDataSourceProvider), isNotNull);
  });

  test('signOut cancels both water and Ramadan reminders', () async {
    final repository = MockAuthRepository();
    when(() => repository.currentUser).thenReturn(null);
    when(
      () => repository.authStateChanges(),
    ).thenAnswer((_) => const Stream.empty());
    when(() => repository.signOut()).thenAnswer((_) async => const Right(null));

    final subscription = _MockSubscriptionService();
    when(() => subscription.logOut()).thenAnswer((_) async {});

    final notifications = _MockNotificationService();
    when(() => notifications.cancelWaterReminders()).thenAnswer((_) async {});
    when(
      () => notifications.cancelRamadanNotifications(),
    ).thenAnswer((_) async {});

    final session = _FakeAppSessionController();

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        subscriptionServiceProvider.overrideWithValue(subscription),
        notificationServiceProvider.overrideWithValue(notifications),
        appSessionControllerProvider.overrideWithValue(session),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.notifier).signOut();

    verify(() => notifications.cancelWaterReminders()).called(1);
    verify(() => notifications.cancelRamadanNotifications()).called(1);
    expect(session.exitCalls, 1);
  });
}
