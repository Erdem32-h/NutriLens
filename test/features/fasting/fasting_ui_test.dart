import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/widgets/app_button.dart';
import 'package:nutrilens/features/fasting/presentation/fasting_actions.dart';
import 'package:nutrilens/features/fasting/presentation/providers/fasting_provider.dart';
import 'package:nutrilens/features/fasting/presentation/screens/fasting_screen.dart';
import 'package:nutrilens/features/fasting/presentation/widgets/fasting_card.dart';
import 'package:nutrilens/features/profile/presentation/screens/profile_screen.dart';
import 'package:nutrilens/features/ramadan/presentation/providers/ramadan_provider.dart';

import '../ramadan/ramadan_widget_harness.dart';

// Ramadan 2027 runs from 2027-02-08; 12:00 on the 1st of Feb is well outside.
final _t0 = DateTime(2027, 2, 1, 12);

class _Clock {
  DateTime value;
  _Clock(this.value);
}

Future<(RamadanHarness, _Clock, ProviderContainer)> _pump(
  WidgetTester tester,
  Widget child, {
  bool premium = false,
  bool activeFast = false,
  int targetHours = 16,
  DateTime? now,
}) async {
  final clock = _Clock(now ?? _t0);
  final h = await pumpRamadanWidget(
    tester,
    child,
    now: clock.value,
    overrides: [
      fastingClockProvider.overrideWithValue(() => clock.value),
      isPremiumProvider.overrideWithValue(premium),
    ],
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  );
  final ds = container.read(fastingSessionsLocalDataSourceProvider);
  if (activeFast) {
    await ds.start(
      'user-1',
      startedAt: clock.value,
      targetMinutes: targetHours * 60,
    );
    container.invalidate(activeFastProvider);
    await tester.pumpAndSettle();
  }
  return (h, clock, container);
}

Future<void> _seedCompleted(ProviderContainer c, DateTime end) async {
  final ds = c.read(fastingSessionsLocalDataSourceProvider);
  final s = await ds.start(
    'user-1',
    startedAt: end.subtract(const Duration(hours: 16)),
    targetMinutes: 16 * 60,
  );
  await ds.end(s.id, end);
  c.invalidate(fastingHistoryProvider);
}

void main() {
  group('FastingCard', () {
    testWidgets('hidden without an active fast', (tester) async {
      await _pump(tester, const FastingCard());
      expect(find.text('Orucu bitir'), findsNothing);
    });

    testWidgets('shows remaining and ticks with the active fast', (
      tester,
    ) async {
      final (_, clock, _) = await _pump(
        tester,
        const FastingCard(),
        activeFast: true,
      );
      expect(find.text('Kalan: 16:00'), findsOneWidget);

      clock.value = clock.value.add(const Duration(hours: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Kalan: 15:00'), findsOneWidget);
    });

    testWidgets('after target shows goal reached and ends without a dialog', (
      tester,
    ) async {
      final (h, clock, _) = await _pump(
        tester,
        const FastingCard(),
        activeFast: true,
      );
      when(
        () => h.notifications.cancelFastingTarget(),
      ).thenAnswer((_) async {});
      clock.value = clock.value.add(const Duration(hours: 17));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Hedefe ulaştın 🎉'), findsOneWidget);

      await tester.tap(find.text('Orucu bitir'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Hedefe ulaştın 🎉'), findsNothing);
    });

    testWidgets('before target asks for confirmation; cancel keeps the fast', (
      tester,
    ) async {
      final (h, _, _) = await _pump(
        tester,
        const FastingCard(),
        activeFast: true,
      );
      when(
        () => h.notifications.cancelFastingTarget(),
      ).thenAnswer((_) async {});

      await tester.tap(find.text('Orucu bitir'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Orucu erken bitir?'), findsOneWidget);

      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Kalan: 16:00'), findsOneWidget);

      await tester.tap(find.text('Orucu bitir'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Orucu bitir'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kalan: 16:00'), findsNothing);
    });
  });

  group('FastingScreen', () {
    testWidgets('free user sees the premium teaser, not the streak', (
      tester,
    ) async {
      await _pump(tester, const FastingScreen());
      expect(find.text('Seri ve geçmiş Premium ile'), findsOneWidget);
    });

    testWidgets('premium user sees streak and average', (tester) async {
      final (_, clock, c) = await _pump(
        tester,
        const FastingScreen(),
        premium: true,
      );
      await _seedCompleted(c, clock.value);
      await tester.pumpAndSettle();
      expect(find.text('Seri ve geçmiş Premium ile'), findsNothing);
      expect(find.text('1 gün seri'), findsOneWidget);
      expect(find.text('Ortalama: 16:00'), findsOneWidget);
    });

    testWidgets('Ramadan block shows info and disables Start', (tester) async {
      final (_, _, c) = await _pump(
        tester,
        const FastingScreen(),
        now: DateTime(2027, 2, 10, 12),
      );
      await c.read(ramadanSettingsProvider.notifier).setEnabled(true);
      await tester.pumpAndSettle();

      expect(
        find.text('Ramazan modu açıkken aralıklı oruç duraklatılır.'),
        findsOneWidget,
      );
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNull,
      );
    });

    testWidgets('Start creates an active fast', (tester) async {
      final (_, _, c) = await _pump(tester, const FastingScreen());
      await tester.tap(find.text('Orucu başlat'));
      await tester.pumpAndSettle();
      expect(await c.read(activeFastProvider.future), isNotNull);
    });
  });

  group('ProfileScreen fasting row', () {
    Future<ProviderContainer> pumpProfile(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      PackageInfo.setMockInitialValues(
        appName: 'NutriLens',
        packageName: 'app.nutrilens',
        version: '0.0.0',
        buildNumber: '0',
        buildSignature: '',
      );
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserProvider.overrideWithValue(null),
            isPremiumProvider.overrideWithValue(false),
            effectiveUserIdProvider.overrideWithValue(null),
            fastingClockProvider.overrideWithValue(
              () => DateTime(2027, 2, 10, 12),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('tr'),
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(ProfileScreen)),
      );
    }

    testWidgets('visible normally, hidden while Ramadan blocks', (
      tester,
    ) async {
      final c = await pumpProfile(tester);
      expect(find.text('Aralıklı Oruç'), findsWidgets);

      await c.read(ramadanSettingsProvider.notifier).setEnabled(true);
      await tester.pumpAndSettle();
      expect(find.text('Aralıklı Oruç'), findsNothing);
    });
  });

  test('formatFastDuration is locale-neutral H:MM', () {
    expect(formatFastDuration(const Duration(hours: 14, minutes: 5)), '14:05');
    expect(formatFastDuration(Duration.zero), '0:00');
  });
}
