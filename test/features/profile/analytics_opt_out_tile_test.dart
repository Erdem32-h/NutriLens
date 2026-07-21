import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/core/analytics/analytics_service.dart';
import 'package:nutrilens/core/services/device_id_service.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/profile/presentation/widgets/analytics_opt_out_tile.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(Widget, AnalyticsService)> _harness({bool optedOut = false}) async {
  SharedPreferences.setMockInitialValues(
    optedOut ? {'analytics.opt_out_v1': true} : <String, Object>{},
  );
  final prefs = await SharedPreferences.getInstance();
  final service = AnalyticsService(
    client: null,
    deviceId: DeviceIdService(prefs),
    prefs: prefs,
    // No periodic timer: flutter_test fails the test if one is still pending
    // when the widget tree is torn down.
    flushInterval: Duration.zero,
  );

  final widget = ProviderScope(
    overrides: [analyticsServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      // AppColorsExtension lives in ThemeData.extensions; without a real
      // theme every context.colors lookup asserts.
      theme: AppTheme.light,
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(body: AnalyticsOptOutTile()),
    ),
  );
  return (widget, service);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reads as on when the user has not opted out', (tester) async {
    final (widget, service) = await _harness();
    addTearDown(service.dispose);

    await tester.pumpWidget(widget);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('reflects a stored opt-out on first build', (tester) async {
    final (widget, service) = await _harness(optedOut: true);
    addTearDown(service.dispose);

    await tester.pumpWidget(widget);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('turning it off stops recording and drops the queue', (
    tester,
  ) async {
    final (widget, service) = await _harness();
    addTearDown(service.dispose);
    await tester.pumpWidget(widget);

    service.track(FunnelEvents.appOpened);
    expect(service.pendingCount, 1);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(service.isOptedOut, isTrue);
    expect(
      service.pendingCount,
      0,
      reason: 'already-queued events must be discarded, not sent later',
    );
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    service.track(FunnelEvents.scannerOpened);
    expect(service.pendingCount, 0, reason: 'opted out means no new events');
  });

  testWidgets('turning it back on resumes recording', (tester) async {
    final (widget, service) = await _harness(optedOut: true);
    addTearDown(service.dispose);
    await tester.pumpWidget(widget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(service.isOptedOut, isFalse);
    service.track(FunnelEvents.appOpened);
    expect(service.pendingCount, 1);
  });

  testWidgets('the choice survives a rebuild of the tile', (tester) async {
    final (widget, service) = await _harness();
    addTearDown(service.dispose);
    await tester.pumpWidget(widget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // Same prefs, freshly mounted tile — the switch must not spring back on.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(widget);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
