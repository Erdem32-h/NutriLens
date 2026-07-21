import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/features/auth/domain/entities/user_entity.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a container with a real (mocked-storage) SharedPreferences and
/// no signed-in user, i.e. the state of a fresh install.
Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
  UserEntity? user,
  bool withPreferences = true,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final instance = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      if (withPreferences) sharedPreferencesProvider.overrideWithValue(instance),
      currentUserProvider.overrideWithValue(user),
    ],
  );
}

void main() {
  group('hasSeenOnboardingProvider', () {
    test('is false on a fresh install so the intro is shown first', () async {
      final container = await _container();
      addTearDown(container.dispose);

      expect(container.read(hasSeenOnboardingProvider), isFalse);
    });

    test('is true once the intro has been completed', () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container.read(appSessionControllerProvider).completeOnboarding();

      expect(container.read(hasSeenOnboardingProvider), isTrue);
    });

    test('reads a persisted flag from a previous launch', () async {
      final container = await _container(prefs: {kOnboardingSeenKey: true});
      addTearDown(container.dispose);

      expect(container.read(hasSeenOnboardingProvider), isTrue);
    });

    // sharedPreferencesProvider throws when un-overridden, which is what
    // main() leaves in place if the plugin failed at boot. The session
    // lookups run inside the GoRouter redirect, so throwing there would
    // take navigation down; returning "already seen" keeps a returning
    // user out of an intro loop.
    test('defaults to true when preferences are unavailable', () async {
      final container = await _container(withPreferences: false);
      addTearDown(container.dispose);

      expect(container.read(hasSeenOnboardingProvider), isTrue);
    });
  });

  group('appSessionProvider', () {
    test('a fresh install is logged out', () async {
      final container = await _container();
      addTearDown(container.dispose);

      expect(container.read(appSessionProvider), AppSessionState.loggedOut);
      expect(container.read(effectiveUserIdProvider), isNull);
    });

    test('entering guest mode scopes local data to the guest sentinel',
        () async {
      final container = await _container();
      addTearDown(container.dispose);

      await container.read(appSessionControllerProvider).enterGuestMode();

      expect(container.read(appSessionProvider), AppSessionState.guest);
      expect(container.read(isGuestProvider), isTrue);
      expect(container.read(effectiveUserIdProvider), kGuestUserId);
    });

    test('an authenticated user outranks a stale guest flag', () async {
      final container = await _container(
        prefs: {'app.guest_mode_v1': true},
        user: const UserEntity(id: 'user-1', email: 'a@b.com'),
      );
      addTearDown(container.dispose);

      expect(
        container.read(appSessionProvider),
        AppSessionState.authenticated,
      );
      expect(container.read(effectiveUserIdProvider), 'user-1');
    });

    test('does not throw when preferences are unavailable', () async {
      final container = await _container(withPreferences: false);
      addTearDown(container.dispose);

      expect(container.read(appSessionProvider), AppSessionState.loggedOut);
    });
  });
}
