import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/features/ramadan/domain/ramadan_calendar.dart';
import 'package:nutrilens/features/ramadan/presentation/providers/ramadan_provider.dart';
import 'package:nutrilens/features/ramadan/presentation/widgets/ramadan_countdown_card.dart';
import 'package:nutrilens/features/ramadan/presentation/widgets/ramadan_offer_card.dart';

import 'ramadan_widget_harness.dart';

// Ramadan 2027 firstDay is 2027-02-08 (offer window opens 2027-02-05) and
// Ankara's coordinates from `turkish_cities.dart` — verified once against
// `fastingTimes()` directly: 8 Feb imsak 06:18/iftar 18:23, 9 Feb imsak
// 06:17/iftar 18:24.
const _ankaraLat = 39.9334;
const _ankaraLng = 32.8597;

Future<ProviderContainer> _enableRamadan(
  WidgetTester tester,
  Type widgetType, {
  double lat = _ankaraLat,
  double lng = _ankaraLng,
  String label = 'Ankara',
  int? plate = 6,
}) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(widgetType)),
  );
  await container
      .read(ramadanSettingsProvider.notifier)
      .setLocation(lat: lat, lng: lng, label: label, plate: plate);
  await container.read(ramadanSettingsProvider.notifier).setEnabled(true);
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('RamadanOfferCard', () {
    testWidgets(
      '5 Şubat, mod kapalı: kart görünür ve tek seferlik izlenir',
      (tester) async {
        final h = await pumpRamadanWidget(
          tester,
          const RamadanOfferCard(),
          now: DateTime(2027, 2, 5),
        );

        expect(find.text('Ramazan modu'), findsOneWidget);
        expect(
          h.analytics.names.where((n) => n == 'ramadan_offer_shown').length,
          1,
        );

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Ramazan modu'), findsNothing);

        // Rebuild while staying mounted (same year) — still gone, still
        // only tracked once.
        await tester.pump();
        expect(find.text('Ramazan modu'), findsNothing);
        expect(
          h.analytics.names.where((n) => n == 'ramadan_offer_shown').length,
          1,
        );
      },
    );

    testWidgets('4 Şubat: teklif penceresi henüz açılmadı, kart yok', (
      tester,
    ) async {
      final h = await pumpRamadanWidget(
        tester,
        const RamadanOfferCard(),
        now: DateTime(2027, 2, 4),
      );

      expect(find.text('Ramazan modu'), findsNothing);
      expect(h.analytics.names, isEmpty);
    });

    testWidgets('CTA -> il seçici -> Ankara -> plaka 6 ile mod açılır, '
        'bildirim izni bir kez istenir', (
      tester,
    ) async {
      final h = await pumpRamadanWidget(
        tester,
        const RamadanOfferCard(),
        now: DateTime(2027, 2, 5),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Ankara');
      await tester.pumpAndSettle();
      // Two "Ankara" matches now: the typed search field's own text and
      // the filtered list tile — the tile is the last one in tree order.
      await tester.tap(find.text('Ankara').last);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(RamadanOfferCard)),
      );
      final settings = container.read(ramadanSettingsProvider);
      expect(settings.enabled, isTrue);
      expect(settings.location?.plate, 6);
      verify(() => h.notifications.requestPermission()).called(1);
    });

    testWidgets('izin reddedilse de mod açılır', (tester) async {
      final h = await pumpRamadanWidget(
        tester,
        const RamadanOfferCard(),
        now: DateTime(2027, 2, 5),
      );
      when(
        () => h.notifications.requestPermission(),
      ).thenAnswer((_) async => false);

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ankara');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ankara').last);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(RamadanOfferCard)),
      );
      expect(container.read(ramadanSettingsProvider).enabled, isTrue);
      verify(() => h.notifications.requestPermission()).called(1);
    });

    testWidgets(
      'Konumumu kullan konum alamazsa snackbar gösterir, sheet açık kalır',
      (tester) async {
        final h = await pumpRamadanWidget(
          tester,
          const RamadanOfferCard(),
          now: DateTime(2027, 2, 5),
        );
        h.setPosition(null);

        await tester.tap(find.text('Aç'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Konumumu kullan'));
        await tester.pumpAndSettle();

        expect(
          find.text('Konum alınamadı, listeden ilini seç.'),
          findsOneWidget,
        );
        // Sheet is still open — the search field is still on screen.
        expect(find.byType(TextField), findsOneWidget);
      },
    );
  });

  group('RamadanCountdownCard', () {
    testWidgets('mod açık, 8 Şubat 12:00 (Ankara) -> İftara 6 sa 23 dk', (
      tester,
    ) async {
      await pumpRamadanWidget(
        tester,
        const RamadanCountdownCard(),
        now: DateTime(2027, 2, 8, 12, 0),
      );
      await _enableRamadan(tester, RamadanCountdownCard);

      expect(find.text('İftara 6 sa 23 dk'), findsOneWidget);
    });

    testWidgets(
      'gece yarısını geçince sayaç bugünün (yeni günün) imsakini kullanır '
      '(Review Focus 1)',
      (tester) async {
        final h = await pumpRamadanWidget(
          tester,
          const RamadanCountdownCard(),
          now: DateTime(2027, 2, 8, 20, 0),
        );
        await _enableRamadan(tester, RamadanCountdownCard);

        // 20:00'da 8 Şubat iftarı geçmiş, sayaç 9 Şubat imsakine (06:17)
        // sayıyor: 10 sa 17 dk.
        expect(find.text('Sahura 10 sa 17 dk'), findsOneWidget);

        h.setNow(DateTime(2027, 2, 9, 2, 0));
        await tester.pump(const Duration(minutes: 1));

        expect(find.text('Sahura 4 sa 17 dk'), findsOneWidget);
      },
    );

    testWidgets('iftar 18:23:00, saat 18:21:30 -> İftara 0 sa 2 dk (yukarı yuvarlar)', (
      tester,
    ) async {
      await pumpRamadanWidget(
        tester,
        const RamadanCountdownCard(),
        now: DateTime(2027, 2, 8, 18, 21, 30),
      );
      await _enableRamadan(tester, RamadanCountdownCard);

      expect(find.text('İftara 0 sa 2 dk'), findsOneWidget);
    });

    testWidgets('iftar 18:23:00, saat 18:22:30 -> İftara 0 sa 1 dk', (
      tester,
    ) async {
      await pumpRamadanWidget(
        tester,
        const RamadanCountdownCard(),
        now: DateTime(2027, 2, 8, 18, 22, 30),
      );
      await _enableRamadan(tester, RamadanCountdownCard);

      expect(find.text('İftara 0 sa 1 dk'), findsOneWidget);
    });

    testWidgets('imsak 06:17, saat 06:15:30 -> Sahura 0 sa 1 dk (aşağı yuvarlar)', (
      tester,
    ) async {
      await pumpRamadanWidget(
        tester,
        const RamadanCountdownCard(),
        now: DateTime(2027, 2, 9, 6, 15, 30),
      );
      await _enableRamadan(tester, RamadanCountdownCard);

      expect(find.text('Sahura 0 sa 1 dk'), findsOneWidget);
    });

    testWidgets('sayaç bir sonraki tam dakikada (:00) tazelenir', (
      tester,
    ) async {
      final h = await pumpRamadanWidget(
        tester,
        const RamadanCountdownCard(),
        now: DateTime(2027, 2, 8, 18, 21, 30),
      );
      await _enableRamadan(tester, RamadanCountdownCard);
      expect(find.text('İftara 0 sa 2 dk'), findsOneWidget);

      h.setNow(DateTime(2027, 2, 8, 18, 22));
      await tester.pump(const Duration(seconds: 30));

      expect(find.text('İftara 0 sa 1 dk'), findsOneWidget);
    });

    testWidgets('son gün 8 Mart 20:00 (son iftardan sonra) -> sayaç yok', (
      tester,
    ) async {
      await pumpRamadanWidget(
        tester,
        const RamadanCountdownCard(),
        now: DateTime(2027, 3, 8, 20),
      );
      await _enableRamadan(tester, RamadanCountdownCard);

      expect(find.textContaining('Sahura'), findsNothing);
      expect(find.textContaining('İftara'), findsNothing);
      expect(find.text('Bugün oruçluyum'), findsOneWidget);
    });

    testWidgets('6 Şubat, mod açık ama Ramazan henüz başlamadı -> kart yok', (
      tester,
    ) async {
      await pumpRamadanWidget(
        tester,
        const RamadanCountdownCard(),
        now: DateTime(2027, 2, 6),
      );
      await _enableRamadan(tester, RamadanCountdownCard);

      expect(find.textContaining('İftara'), findsNothing);
      expect(find.textContaining('Sahura'), findsNothing);
      expect(find.text('Konum seç'), findsNothing);
    });

    testWidgets(
      'mod açık, konum yok -> Konum seç görünür (Review Focus 4)',
      (tester) async {
        final h = await pumpRamadanWidget(
          tester,
          const RamadanCountdownCard(),
          now: DateTime(2027, 2, 8, 12, 0),
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(RamadanCountdownCard)),
        );
        await container.read(ramadanSettingsProvider.notifier).setEnabled(true);
        await tester.pumpAndSettle();

        expect(find.text('Konum seç'), findsOneWidget);
        expect(h.analytics.names, isEmpty);
      },
    );

    testWidgets(
      'Bugün oruçluyum işaretlenince veriye yazılır ve izlenir',
      (tester) async {
        final now = DateTime(2027, 2, 8, 12, 0);
        final h = await pumpRamadanWidget(
          tester,
          const RamadanCountdownCard(),
          now: now,
        );
        final container = await _enableRamadan(tester, RamadanCountdownCard);

        await tester.tap(find.text('Bugün oruçluyum'));
        await tester.pumpAndSettle();

        final days = await container
            .read(fastingDaysLocalDataSourceProvider)
            .getDays('user-1', from: '2027-02-01', toExclusive: '2027-03-09');
        expect(days.contains(ramadanDayKey(now)), isTrue);
        expect(h.analytics.names, contains('ramadan_day_marked'));
      },
    );

    testWidgets(
      'bildirim izni kapalıyken "Bildirimler kapalı — aç" görünür',
      (tester) async {
        await pumpRamadanWidget(
          tester,
          const RamadanCountdownCard(),
          now: DateTime(2027, 2, 8, 12, 0),
          notificationsPermitted: false,
        );
        await _enableRamadan(tester, RamadanCountdownCard);

        expect(find.text('Bildirimler kapalı — aç'), findsOneWidget);
      },
    );

    testWidgets(
      'izin açıksa "Bildirimler kapalı — aç" görünmez',
      (tester) async {
        await pumpRamadanWidget(
          tester,
          const RamadanCountdownCard(),
          now: DateTime(2027, 2, 8, 12, 0),
          notificationsPermitted: true,
        );
        await _enableRamadan(tester, RamadanCountdownCard);

        expect(find.text('Bildirimler kapalı — aç'), findsNothing);
      },
    );

    testWidgets(
      'linke dokununca izin istenir; verilince link kaybolur',
      (tester) async {
        final h = await pumpRamadanWidget(
          tester,
          const RamadanCountdownCard(),
          now: DateTime(2027, 2, 8, 12, 0),
          notificationsPermitted: false,
        );
        await _enableRamadan(tester, RamadanCountdownCard);
        expect(find.text('Bildirimler kapalı — aç'), findsOneWidget);

        // requestPermission() is stubbed to return true by default; simulate
        // the OS having actually granted it so the re-check after tap sees
        // the new state too.
        h.setNotificationsPermitted(true);

        await tester.tap(find.text('Bildirimler kapalı — aç'));
        await tester.pumpAndSettle();

        verify(() => h.notifications.requestPermission()).called(1);
        expect(find.text('Bildirimler kapalı — aç'), findsNothing);
      },
    );
  });
}
