import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/core/widgets/app_button.dart';
import 'package:nutrilens/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The smallest screen we realistically ship to (iPhone SE / low-end
/// Android). Onboarding is the first launch destination, so a layout
/// overflow here is the very first thing a new user would see.
const _smallPhone = Size(375, 667);

Future<ProviderContainer> _pumpOnboarding(WidgetTester tester) async {
  tester.view.physicalSize = _smallPhone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserProvider.overrideWithValue(null),
    ],
  );
  addTearDown(container.dispose);

  // A real router, so the screen's context.go calls resolve and the test can
  // assert *where* the intro sends people — the whole point of the change.
  final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(
        path: '/scanner',
        builder: (_, _) => const Scaffold(body: Text('scanner')),
      ),
      GoRoute(
        path: '/login',
        builder: (_, _) => const Scaffold(body: Text('login')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders on a 375x667 screen without overflowing', (
    tester,
  ) async {
    await _pumpOnboarding(tester);

    // A RenderFlex overflow reports itself as a thrown exception during
    // layout, which pumpWidget surfaces here.
    expect(tester.takeException(), isNull);
  });

  testWidgets('offers both a start CTA and a sign-in escape hatch', (
    tester,
  ) async {
    await _pumpOnboarding(tester);

    // The primary path (start free as a guest) and the returning-user path
    // must both be reachable from the first page — a reinstalling user
    // should not have to page through the intro to find sign-in.
    expect(find.byType(AppButton), findsOneWidget);
    expect(find.text('Zaten hesabım var'), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);
  });

  testWidgets('completing the intro enters guest mode', (tester) async {
    final container = await _pumpOnboarding(tester);

    expect(container.read(hasSeenOnboardingProvider), isFalse);
    expect(container.read(appSessionProvider), AppSessionState.loggedOut);

    // "Atla" is the fast path through the intro; it must land the user in
    // the app as a guest rather than on the login form. Dropping them on
    // /login here would rebuild the signup wall this screen exists to
    // replace.
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(container.read(hasSeenOnboardingProvider), isTrue);
    expect(container.read(appSessionProvider), AppSessionState.guest);
    expect(find.text('scanner'), findsOneWidget);
  });

  testWidgets('"I already have an account" goes to login, not guest mode', (
    tester,
  ) async {
    final container = await _pumpOnboarding(tester);

    await tester.tap(find.text('Zaten hesabım var'));
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    // The intro is marked seen either way, so a returning user who backs
    // out of login is not thrown into the intro again on next launch.
    expect(container.read(hasSeenOnboardingProvider), isTrue);
    expect(container.read(appSessionProvider), AppSessionState.loggedOut);
  });
}
