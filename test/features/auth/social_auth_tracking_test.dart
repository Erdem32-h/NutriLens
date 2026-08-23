import 'package:flutter/material.dart';
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
import 'package:nutrilens/features/auth/domain/repositories/auth_repository.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/features/auth/presentation/providers/social_auth_tracking.dart';
import 'package:nutrilens/features/auth/presentation/widgets/social_login_buttons.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

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
