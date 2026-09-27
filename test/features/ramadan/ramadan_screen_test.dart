import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/services/share_service.dart';
import 'package:nutrilens/features/ramadan/domain/ramadan_schedule.dart';
import 'package:nutrilens/features/ramadan/presentation/providers/ramadan_provider.dart';
import 'package:nutrilens/features/ramadan/presentation/screens/ramadan_screen.dart';
import 'package:nutrilens/features/ramadan/presentation/widgets/ramadan_share_card.dart';
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';

import 'ramadan_widget_harness.dart';

// Ramadan 2027 firstDay is 2027-02-08 (29 days, Eid 2027-03-09) — matches
// `ramadan_calendar.dart` and the other Task 6/7 tests.
const _ankaraLat = 39.9334;
const _ankaraLng = 32.8597;

class MockShareService extends Mock implements ShareService {}

class _FakeBuildContext extends Fake implements BuildContext {}

Future<ProviderContainer> _setLocationAndEnable(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(RamadanScreen)),
  );
  await container
      .read(ramadanSettingsProvider.notifier)
      .setLocation(lat: _ankaraLat, lng: _ankaraLng, label: 'Ankara', plate: 6);
  await container.read(ramadanSettingsProvider.notifier).setEnabled(true);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeBuildContext());
    registerFallbackValue(const SizedBox());
    registerFallbackValue(const Size(0, 0));
  });

  group('fastingStreak', () {
    test('bugun dahil ama isaretlenmemis -> dune kadar sayilir', () {
      expect(
        fastingStreak({'2027-02-08', '2027-02-09'}, DateTime(2027, 2, 10)),
        2,
      );
    });

    test('bugun de isaretliyse bugun dahil sayilir', () {
      expect(
        fastingStreak({
          '2027-02-08',
          '2027-02-09',
          '2027-02-10',
        }, DateTime(2027, 2, 10)),
        3,
      );
    });

    test('dun isaretli degilse seri 0', () {
      expect(fastingStreak({'2027-02-08'}, DateTime(2027, 2, 10)), 0);
    });
  });

  group('RamadanScreen', () {
    testWidgets(
      '29 gunluk izgara, 10 Subatta 4. gun ve sonrasi kapali, 1. gune '
      'dokununca isaretlenir',
      (tester) async {
        await pumpRamadanWidget(
          tester,
          const RamadanScreen(),
          now: DateTime(2027, 2, 10),
        );

        for (var i = 1; i <= 29; i++) {
          expect(find.byKey(ValueKey('ramadan-day-$i')), findsOneWidget);
        }
        expect(find.text('0/29 gün'), findsOneWidget);

        // 4. gun (11 Subat) bugunden (10 Subat) sonraki bir gun -> kapali,
        // dokunma hicbir sey degistirmez.
        await tester.tap(find.byKey(const ValueKey('ramadan-day-4')));
        await tester.pumpAndSettle();
        expect(find.text('0/29 gün'), findsOneWidget);

        // 1. gun (8 Subat) acik -> dokununca isaretlenir.
        await tester.tap(find.byKey(const ValueKey('ramadan-day-1')));
        await tester.pumpAndSettle();
        expect(find.text('1/29 gün'), findsOneWidget);
      },
    );

    testWidgets(
      'teklif penceresinde (6 Subat) ekran bos degil: 29 gunluk izgara, '
      'hepsi gelecek gun',
      (tester) async {
        await pumpRamadanWidget(
          tester,
          const RamadanScreen(),
          now: DateTime(2027, 2, 6),
        );

        expect(find.text('0/29 gün'), findsOneWidget);
        final day1 = tester.widget<GestureDetector>(
          find.byKey(const ValueKey('ramadan-day-1')),
        );
        expect(day1.onTap, isNull);
      },
    );

    testWidgets('Bayramdan sonra (15 Mart) mod anahtari devre disi', (
      tester,
    ) async {
      await pumpRamadanWidget(
        tester,
        const RamadanScreen(),
        now: DateTime(2027, 3, 15),
      );

      await tester.dragUntilVisible(
        find.byType(Switch),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
    });

    testWidgets('2 gun isaretlenince baslik "2/29 gün" gosterir', (
      tester,
    ) async {
      await pumpRamadanWidget(
        tester,
        const RamadanScreen(),
        now: DateTime(2027, 2, 10),
      );

      await tester.tap(find.byKey(const ValueKey('ramadan-day-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ramadan-day-2')));
      await tester.pumpAndSettle();

      expect(find.text('2/29 gün'), findsOneWidget);
    });

    testWidgets('mod anahtari kapatilinca disable cagrilir', (tester) async {
      final h = await pumpRamadanWidget(
        tester,
        const RamadanScreen(),
        now: DateTime(2027, 2, 10),
      );
      final container = await _setLocationAndEnable(tester);

      await tester.dragUntilVisible(
        find.byType(Switch),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(ramadanSettingsProvider).enabled, isFalse);
      verify(() => h.notifications.cancelRamadanNotifications()).called(1);
    });

    testWidgets(
      'konum satirina dokununca sehir secici acilir, Ankara secilince '
      'plaka 6 ile kaydedilir',
      (tester) async {
        await pumpRamadanWidget(
          tester,
          const RamadanScreen(),
          now: DateTime(2027, 2, 10),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(RamadanScreen)),
        );

        await tester.dragUntilVisible(
          find.text('Konum seç'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Konum seç'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Ankara');
        await tester.pumpAndSettle();
        // Two "Ankara" matches: the typed search field's own text and the
        // filtered list tile — the tile is last in tree order.
        await tester.tap(find.text('Ankara').last);
        await tester.pumpAndSettle();

        final location = container.read(ramadanSettingsProvider).location;
        expect(location?.label, 'Ankara');
        expect(location?.plate, 6);
      },
    );

    testWidgets('konum kayitliyken mod acilinca sehir secici acilmadan enable '
        'cagrilir', (tester) async {
      final h = await pumpRamadanWidget(
        tester,
        const RamadanScreen(),
        now: DateTime(2027, 2, 10),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RamadanScreen)),
      );
      await container
          .read(ramadanSettingsProvider.notifier)
          .setLocation(
            lat: _ankaraLat,
            lng: _ankaraLng,
            label: 'Ankara',
            plate: 6,
          );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.byType(Switch),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(ramadanSettingsProvider).enabled, isTrue);
      expect(h.analytics.names, contains('ramadan_enabled'));
      // The city picker's search field never appeared.
      expect(find.byType(TextField), findsNothing);
      verify(() => h.notifications.requestPermission()).called(1);
    });

    testWidgets("bugunun hucresi (gun 3, 10 Subat'ta) cerceveli, gun 2 degil", (
      tester,
    ) async {
      await pumpRamadanWidget(
        tester,
        const RamadanScreen(),
        now: DateTime(2027, 2, 10),
      );

      BoxDecoration decorationOf(int index) =>
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byKey(ValueKey('ramadan-day-$index')),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;

      expect(decorationOf(3).border, isNotNull);
      expect(decorationOf(2).border, isNull);
    });

    testWidgets(
      'sahur cipi 60 secilince YENI offsetle (60) yeniden planlanir',
      (tester) async {
        final h = await pumpRamadanWidget(
          tester,
          const RamadanScreen(),
          now: DateTime(2027, 2, 10),
        );
        final container = await _setLocationAndEnable(tester);

        await tester.dragUntilVisible(
          find.text('60 dk önce'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('60 dk önce'));
        await tester.pumpAndSettle();

        expect(container.read(ramadanSettingsProvider).sahurOffsetMin, 60);
        final items =
            verify(
                  () => h.notifications.rescheduleRamadanNotifications(
                    items: captureAny(named: 'items'),
                    sahurTitle: any(named: 'sahurTitle'),
                    sahurBody: any(named: 'sahurBody'),
                    iftarTitle: any(named: 'iftarTitle'),
                    iftarBody: any(named: 'iftarBody'),
                  ),
                ).captured.last
                as List<RamadanNotification>;
        // The sahur item must be built from the NEW offset (60 min before
        // imsak), not the offset that was selected before the tap (45) —
        // see task-8-brief ruling. The body itself no longer encodes the
        // offset (D2 — it states the absolute imsak time instead), so this
        // asserts on the scheduled gap between imsakAt and at.
        final sahur = items.firstWhere(
          (n) => n.kind == RamadanNotificationKind.sahur,
        );
        expect(sahur.imsakAt!.difference(sahur.at).inMinutes, 60);
      },
    );

    testWidgets(
      'paylas butonu captureAndShare cagirir, dogru fileName/analitikle',
      (tester) async {
        final mockShare = MockShareService();
        when(
          () => mockShare.captureAndShare(
            context: any(named: 'context'),
            card: any(named: 'card'),
            logicalSize: any(named: 'logicalSize'),
            pixelRatio: any(named: 'pixelRatio'),
            fileName: any(named: 'fileName'),
            caption: any(named: 'caption'),
          ),
        ).thenAnswer((_) async {});

        final h = await pumpRamadanWidget(
          tester,
          const RamadanScreen(),
          now: DateTime(2027, 2, 10),
          overrides: [shareServiceProvider.overrideWithValue(mockShare)],
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(RamadanScreen)),
        );

        // 2 gun oruc isaretle.
        await container
            .read(ramadanControllerProvider)
            .setFasted(DateTime(2027, 2, 8), true);
        await container
            .read(ramadanControllerProvider)
            .setFasted(DateTime(2027, 2, 9), true);

        // Su: 8 ve 9 Subat'ta 2'ser bardak (200 ml) -> toplam 800 ml = 0.8 L.
        final waterDs = container.read(waterLocalDataSourceProvider);
        for (final day in [
          DateTime(2027, 2, 8, 20),
          DateTime(2027, 2, 9, 20),
        ]) {
          await waterDs.addGlass(userId: 'user-1', now: day, goal: 10);
          await waterDs.addGlass(userId: 'user-1', now: day, goal: 10);
        }
        await tester.pumpAndSettle();

        await tester.dragUntilVisible(
          find.text('Ramazan özetimi paylaş'),
          find.byType(ListView),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ramazan özetimi paylaş'));
        await tester.pumpAndSettle();

        final captured = verify(
          () => mockShare.captureAndShare(
            context: any(named: 'context'),
            card: captureAny(named: 'card'),
            logicalSize: const Size(360, 640),
            pixelRatio: 3.0,
            fileName: 'nutrilens-ramadan-2027.png',
            caption: any(named: 'caption'),
          ),
        ).captured;

        final card = captured.single as RamadanShareCard;
        expect(card.fasted, 2);
        expect(card.total, 29);
        expect(card.liters, closeTo(0.8, 0.001));
        expect(h.analytics.names, contains('ramadan_summary_shared'));
      },
    );
  });
}
