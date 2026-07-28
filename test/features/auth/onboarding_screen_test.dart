import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/device_id_service.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/core/widgets/app_button.dart';
import 'package:nutrilens/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The smallest screen we realistically ship to (iPhone SE / low-end
/// Android). Onboarding is the first launch destination, so a layout
/// overflow here is the very first thing a new user would see.
const _smallPhone = Size(375, 667);

/// Supabase'e gitmek yerine gönderilen partileri yakalar — analytics
/// servisinin kendi testlerindeki desenin aynısı.
class _RecordingUploader {
  final List<List<Map<String, Object?>>> batches = [];

  Future<void> call({
    required String deviceHash,
    required List<Map<String, Object?>> events,
  }) async {
    batches.add(events);
  }
}

Future<ProviderContainer> _pumpOnboarding(
  WidgetTester tester, {
  _RecordingUploader? uploader,
  ThemeData? theme,
  Locale locale = const Locale('tr'),
}) async {
  tester.view.physicalSize = _smallPhone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // flushInterval sıfır: flutter_test, widget ağacından uzun yaşayan bir
  // timer'a izin vermiyor ve bunu tearDown'dan ÖNCE denetliyor.
  final analytics = AnalyticsService(
    client: null,
    deviceId: DeviceIdService(prefs),
    prefs: prefs,
    uploader: uploader?.call,
    flushInterval: Duration.zero,
  );
  addTearDown(analytics.dispose);

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      currentUserProvider.overrideWithValue(null),
      analyticsServiceProvider.overrideWithValue(analytics),
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
        path: '/meals',
        builder: (_, _) => const Scaffold(body: Text('meals')),
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
        theme: theme ?? AppTheme.light,
        locale: locale,
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
  // AnalyticsService.flush() reads the app version via
  // PackageInfo.fromPlatform(). Under a plain test() that throws
  // MissingPluginException instantly (caught, harmless) — but under
  // testWidgets() on this Windows host it hangs indefinitely instead of
  // throwing, which stalls flush() forever. This mock short-circuits the
  // platform channel so the one test below that awaits flush() doesn't
  // hang. Real devices are unaffected — this only patches the test binding.
  PackageInfo.setMockInitialValues(
    appName: 'NutriLens',
    packageName: 'app.nutrilens',
    version: '0.0.0',
    buildNumber: '0',
    buildSignature: '',
  );

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
    // /meals, not /scanner: the scanner opens a camera from initState, so
    // routing there would greet a first-time visitor with an OS permission
    // dialog before they had asked for the camera.
    expect(find.text('meals'), findsOneWidget);
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

  testWidgets('ilk sayfa gorunumu de olay olarak isaretlenir', (tester) async {
    final uploader = _RecordingUploader();
    final container = await _pumpOnboarding(tester, uploader: uploader);

    await container.read(analyticsServiceProvider).flush();

    // onboarding_page_viewed bugune kadar yalnizca onPageChanged'de
    // atesleniyordu, yani sayfa 0 hic olcumlenmiyordu ve huni ancak
    // onboarding_shown'dan cikarim yapilarak okunabiliyordu.
    final events = uploader.batches.expand((b) => b).toList();
    expect(
      events.where(
        (e) =>
            e['event'] == FunnelEvents.onboardingPageViewed &&
            (e['props'] as Map)['page'] == 0,
      ),
      hasLength(1),
    );
  });

  testWidgets('koyu temada 375x667 ekranda tasma yok', (tester) async {
    await _pumpOnboarding(tester, theme: AppTheme.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arapca (RTL) 375x667 ekranda tasma yok', (tester) async {
    // En uzun ceviriler ve ters yon duzeni birlikte en zorlu durum.
    await _pumpOnboarding(tester, locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uc sayfa da kaydirilarak gezilebilir', (tester) async {
    await _pumpOnboarding(tester);

    // Sayfa 0 -> 1
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Katkı maddeleri, şeker ve tuz tek bakışta.'), findsOneWidget);

    // Sayfa 1 -> 2
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Alerjenini ve diyetini seç, sakıncalıyı hemen gör.'), findsOneWidget);
    // Son sayfada birincil eylem "Ucretsiz basla" olur.
    expect(find.text('Ücretsiz başla'), findsOneWidget);
  });
}
