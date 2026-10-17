import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/error/failures.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/core/widgets/app_button.dart';
import 'package:nutrilens/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:nutrilens/features/auth/domain/repositories/auth_repository.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/features/auth/presentation/providers/social_auth_tracking.dart';
import 'package:nutrilens/features/auth/presentation/widgets/social_login_buttons.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
// LinkDelegate lives in its own entrypoint, not the package barrel.
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Counts in-app browser dismissals; nothing in these tests launches.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  int closeCalls = 0;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<void> closeWebView() async => closeCalls++;
}

/// Captures what the widget reports instead of queueing it. The production
/// service is disabled outside release builds, so a real one would swallow
/// every call and these tests would pass vacuously.
class _RecordingAnalytics extends AnalyticsService {
  _RecordingAnalytics()
    : super(
        client: null,
        deviceId: null,
        prefs: null,
        enabled: false,
        flushInterval: Duration.zero,
      );

  final calls = <(String, Map<String, Object?>)>[];

  @override
  void track(String name, {Map<String, Object?> props = const {}}) {
    calls.add((name, props));
  }

  List<Map<String, Object?>> propsFor(String name) =>
      calls.where((c) => c.$1 == name).map((c) => c.$2).toList();
}

void main() {
  late _MockAuthRepository repository;
  late _RecordingAnalytics analytics;

  setUp(() {
    repository = _MockAuthRepository();
    analytics = _RecordingAnalytics();
    when(() => repository.currentUser).thenReturn(null);
  });

  Widget subject() => ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      authRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Themed via the extension alone — AppTheme pulls in google_fonts,
      // which throws when evaluated outside a test zone.
      theme: ThemeData(extensions: const [AppColorsExtension.light]),
      home: const Scaffold(body: SocialLoginButtons()),
    ),
  );

  group('social sign-in reporting', () {
    testWidgets('tapping Google reports the attempt with its method', (
      tester,
    ) async {
      when(
        () => repository.signInWithGoogle(),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(subject());
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      final started = analytics.propsFor(FunnelEvents.loginStarted);
      expect(started, hasLength(1));
      expect(started.single['method'], 'google');
    });

    testWidgets('a launch that never reaches the browser is reported as a '
        'failure, not left pending', (tester) async {
      when(
        () => repository.signInWithGoogle(),
      ).thenAnswer((_) async => const Left(NetworkFailure()));

      await tester.pumpWidget(subject());
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      final failed = analytics.propsFor(FunnelEvents.loginFailed);
      expect(failed, hasLength(1));
      expect(failed.single['method'], 'google');
      expect(failed.single['reason'], 'network_failure');

      // A failed launch must not leave a method parked, or the next
      // successful sign-in would be attributed to this abandoned one.
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(SocialLoginButtons)),
      );
      expect(scope.read(pendingSocialAuthProvider), isNull);
    });

    testWidgets('a launched sign-in stays pending until the session lands', (
      tester,
    ) async {
      when(
        () => repository.signInWithGoogle(),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(subject());
      await tester.tap(find.byType(AppButton));
      await tester.pumpAndSettle();

      final scope = ProviderScope.containerOf(
        tester.element(find.byType(SocialLoginButtons)),
      );
      expect(scope.read(pendingSocialAuthProvider), 'google');
      expect(analytics.propsFor(FunnelEvents.loginSucceeded), isEmpty);
    });
  });

  group('completePendingSocialAuth', () {
    final realLauncher = UrlLauncherPlatform.instance;
    late _FakeUrlLauncher launcher;

    setUp(() {
      launcher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
    });
    tearDown(() => UrlLauncherPlatform.instance = realLauncher);

    Widget landing() => ProviderScope(
      overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => completePendingSocialAuth(ref),
            child: const Text('land'),
          ),
        ),
      ),
    );

    testWidgets(
      'reports the parked method once and closes the iOS in-app browser',
      (tester) async {
        await tester.pumpWidget(landing());
        ProviderScope.containerOf(
          tester.element(find.byType(TextButton)),
        ).read(pendingSocialAuthProvider.notifier).start('apple');

        await tester.tap(find.text('land'));
        await tester.tap(find.text('land'));
        await tester.pump();

        final succeeded = analytics.propsFor(FunnelEvents.loginSucceeded);
        expect(succeeded, hasLength(1));
        expect(succeeded.single['method'], 'apple');
        // Otherwise SFSafariViewController stays over the app after sign-in.
        expect(launcher.closeCalls, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'leaves a sign-in with nothing in flight alone',
      (tester) async {
        await tester.pumpWidget(landing());

        await tester.tap(find.text('land'));
        await tester.pump();

        expect(analytics.propsFor(FunnelEvents.loginSucceeded), isEmpty);
        expect(launcher.closeCalls, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  });

  group('isInAppBrowserLoadFailure', () {
    test('recognises the iOS in-app browser failing at our redirect', () {
      // Exactly what url_launcher_ios throws when SFSafariViewController's
      // initial load ends at `nutrilens://auth/callback`.
      expect(
        isInAppBrowserLoadFailure(
          PlatformException(
            code: 'Error',
            message: 'Error while launching https://x.supabase.co/auth/v1/'
                'authorize?provider=apple',
          ),
        ),
        isTrue,
      );
    });

    test('lets launches that never opened a browser fail', () {
      for (final e in [
        PlatformException(code: 'no_ui_available'),
        PlatformException(code: 'argument_error', message: 'Unable to parse URL'),
        PlatformException(code: 'Error'),
      ]) {
        expect(isInAppBrowserLoadFailure(e), isFalse, reason: e.code);
      }
    });
  });

  group('PendingSocialAuth', () {
    test('take() yields the in-flight method exactly once', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pendingSocialAuthProvider.notifier);
      expect(notifier.take(), isNull);

      notifier.start('apple');
      expect(container.read(pendingSocialAuthProvider), 'apple');

      // Once only: the deep link can bring the app back to more than one
      // screen, and each of them asks. A second answer would double count.
      expect(notifier.take(), 'apple');
      expect(notifier.take(), isNull);
    });
  });
}
