import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/services/anthropic_ai_service.dart';
import 'package:nutrilens/core/services/gemini_ai_service.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/scanner/presentation/screens/food_result_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Records what the screen reports instead of queueing it. The production
/// service is disabled in debug builds, so a real one would swallow every
/// call and these tests would pass vacuously.
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

/// Fails `analyzeMeal` on demand. The completer lets a test decide whether the
/// error lands while the screen is still mounted or after the user has left —
/// the distinction the tracking order has to survive.
class _FailingGemini extends GeminiAiService {
  _FailingGemini(this.failure) : super(MockSupabaseClient());

  final Object failure;
  final gate = Completer<void>();

  /// Set once the screen has finished on-device image prep and is waiting on
  /// the network. Tests hold here to decide whether the user is still looking
  /// at the screen when the error arrives.
  bool reached = false;

  @override
  Future<MealAnalysisResult> analyzeMeal(
    String base64Image, {
    String languageCode = 'tr',
    required String deviceHash,
  }) async {
    reached = true;
    await gate.future;
    throw failure;
  }
}

/// Pumps until [done], giving real time to the parts of the analysis that do
/// not run on fake time: `prepareMealAnalysisImage` hands the frame to an
/// isolate via `compute`, which never completes under `pump` alone.
Future<void> _drain(WidgetTester tester, bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Widget _subject(_RecordingAnalytics analytics, GeminiAiService gemini,
    SharedPreferences prefs, Uint8List image) {
  return ProviderScope(
    overrides: [
      analyticsServiceProvider.overrideWithValue(analytics),
      geminiAiServiceProvider.overrideWithValue(gemini),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Themed via the extension alone — AppTheme pulls in google_fonts,
      // which throws when evaluated outside a test zone.
      theme: ThemeData(extensions: const [AppColorsExtension.light]),
      home: FoodResultScreen(imageBytes: image),
    ),
  );
}

void main() {
  late SharedPreferences prefs;
  late Uint8List image;

  setUpAll(() {
    // A real, decodable frame: the screen renders it while loading and the
    // analysis path runs it through prepareMealAnalysisImage first.
    image = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('meal analysis failure tracking', () {
    testWidgets('is recorded even when the user leaves before the error '
        'surfaces', (tester) async {
      final analytics = _RecordingAnalytics();
      final gemini = _FailingGemini(
        const GeminiServiceException('proxy down', statusCode: 503),
      );

      await tester.pumpWidget(_subject(analytics, gemini, prefs, image));
      await _drain(tester, () => gemini.reached);

      // The user backs out of a slow analysis. Before the fix the mounted
      // guard sat above the track() call, so this failure — the one that
      // actually costs a conversion — was dropped entirely.
      await tester.pumpWidget(const SizedBox());
      gemini.gate.complete();
      await _drain(
        tester,
        () => analytics.propsFor(FunnelEvents.mealAnalysisFailed).isNotEmpty,
      );

      final failed = analytics.propsFor(FunnelEvents.mealAnalysisFailed);
      expect(failed, hasLength(1));
      expect(failed.single['abandoned'], isTrue);
      expect(failed.single['reason'], 'service');
    });

    testWidgets('carries the proxy status when the error is shown on screen',
        (tester) async {
      final analytics = _RecordingAnalytics();
      final gemini = _FailingGemini(
        const GeminiServiceException('proxy down', statusCode: 503),
      );

      await tester.pumpWidget(_subject(analytics, gemini, prefs, image));
      await _drain(tester, () => gemini.reached);
      gemini.gate.complete();
      await _drain(
        tester,
        () => analytics.propsFor(FunnelEvents.mealAnalysisFailed).isNotEmpty,
      );

      final failed = analytics.propsFor(FunnelEvents.mealAnalysisFailed);
      expect(failed, hasLength(1));
      expect(failed.single['abandoned'], isFalse);
      expect(failed.single['reason'], 'service');
      expect(failed.single['status'], 503);
    });

    testWidgets('separates an out-of-credit 429 from a plain outage',
        (tester) async {
      final analytics = _RecordingAnalytics();
      final gemini = _FailingGemini(
        const GeminiServiceException('rate limited', statusCode: 429),
      );

      await tester.pumpWidget(_subject(analytics, gemini, prefs, image));
      await _drain(tester, () => gemini.reached);
      gemini.gate.complete();
      await _drain(
        tester,
        () => analytics.propsFor(FunnelEvents.mealAnalysisFailed).isNotEmpty,
      );

      final failed = analytics.propsFor(FunnelEvents.mealAnalysisFailed);
      expect(failed.single['reason'], 'quota');
      expect(failed.single['status'], 429);
    });

    testWidgets('derives a reason for non-service errors instead of a '
        'blanket "error"', (tester) async {
      final analytics = _RecordingAnalytics();
      final gemini = _FailingGemini(
        const SocketException('Failed host lookup'),
      );

      await tester.pumpWidget(_subject(analytics, gemini, prefs, image));
      await _drain(tester, () => gemini.reached);
      gemini.gate.complete();
      await _drain(
        tester,
        () => analytics.propsFor(FunnelEvents.mealAnalysisFailed).isNotEmpty,
      );

      final failed = analytics.propsFor(FunnelEvents.mealAnalysisFailed);
      expect(failed, hasLength(1));
      // 'error' told us nothing; a dead socket and a bad image looked alike.
      expect(failed.single['reason'], 'network');
    });

    testWidgets('the started event still fires exactly once', (tester) async {
      final analytics = _RecordingAnalytics();
      final gemini = _FailingGemini(
        const GeminiServiceException('proxy down', statusCode: 503),
      );

      await tester.pumpWidget(_subject(analytics, gemini, prefs, image));
      await _drain(tester, () => gemini.reached);
      gemini.gate.complete();
      await _drain(
        tester,
        () => analytics.propsFor(FunnelEvents.mealAnalysisFailed).isNotEmpty,
      );

      final started = analytics.propsFor(FunnelEvents.mealAnalysisStarted);
      expect(started, hasLength(1));
      expect(started.single['retry'], isFalse);
    });
  });
}
