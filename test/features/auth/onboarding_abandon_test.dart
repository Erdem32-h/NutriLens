import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

/// Captures what the screen reports instead of queueing it.
///
/// Overriding [track] rather than driving a real service on purpose: the
/// production instance is disabled in debug builds (`!kDebugMode`), so a real
/// one would silently swallow every call and the tests would pass vacuously.
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

Widget _subject(AnalyticsService analytics) => ProviderScope(
  overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    // Themed via the extension alone — AppTheme pulls in google_fonts, which
    // throws when evaluated outside a test zone.
    theme: ThemeData(extensions: const [AppColorsExtension.light]),
    home: const OnboardingScreen(),
  ),
);

void main() {
  group('onboarding abandonment', () {
    testWidgets('sending the app to the background records the page and '
        'the reason', (tester) async {
      final analytics = _RecordingAnalytics();
      await tester.pumpWidget(_subject(analytics));
      await tester.pump();

      // The whole point of the event: quitting onboarding usually means
      // leaving the app, and then dispose never runs.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      final abandoned = analytics.propsFor(FunnelEvents.onboardingAbandoned);
      expect(abandoned, hasLength(1));
      expect(abandoned.single['page'], 0);
      expect(abandoned.single['reason'], 'background');
      expect(abandoned.single['seconds'], isA<int>());
    });

    testWidgets('leaving the screen without using a measured exit records '
        'a disposal', (tester) async {
      final analytics = _RecordingAnalytics();
      await tester.pumpWidget(_subject(analytics));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());

      final abandoned = analytics.propsFor(FunnelEvents.onboardingAbandoned);
      expect(abandoned, hasLength(1));
      expect(abandoned.single['reason'], 'disposed');
    });

    testWidgets('is recorded at most once per visit', (tester) async {
      final analytics = _RecordingAnalytics();
      await tester.pumpWidget(_subject(analytics));
      await tester.pump();

      // Background, return, background again, then leave. Counting each of
      // these would inflate the abandonment rate over the real one.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());

      expect(analytics.propsFor(FunnelEvents.onboardingAbandoned), hasLength(1));
    });

    testWidgets('the existing entry events still fire', (tester) async {
      final analytics = _RecordingAnalytics();
      await tester.pumpWidget(_subject(analytics));
      await tester.pump();

      expect(analytics.propsFor(FunnelEvents.onboardingShown), hasLength(1));
      final pages = analytics.propsFor(FunnelEvents.onboardingPageViewed);
      expect(pages, hasLength(1));
      expect(pages.single['page'], 0);
    });
  });
}
