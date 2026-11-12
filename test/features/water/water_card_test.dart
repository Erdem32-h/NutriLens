import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/core/analytics/analytics_event.dart';
import 'package:nutrilens/core/analytics/analytics_provider.dart';
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';
import 'package:nutrilens/features/water/presentation/widgets/water_card.dart';

import 'water_widget_harness.dart';

void main() {
  testWidgets('baslangicta 0 / 10, eksi pasif', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());

    expect(find.text('0 / 10 bardak'), findsOneWidget);
    final minus = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove_rounded),
    );
    expect(minus.onPressed, isNull);
  });

  testWidgets('+1 sayar, ilk seferde hatirlatma sorusu cikar', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());

    await tester.tap(find.byKey(const ValueKey('water-glass-0')));
    await tester.pumpAndSettle();

    expect(find.text('1 / 10 bardak'), findsOneWidget);
    expect(find.text('Gerideysen hatırlatayım mı?'), findsOneWidget);
  });

  testWidgets('soru ikinci bardakta tekrar cikmaz', (tester) async {
    final h = await pumpWaterWidget(tester, const WaterCard());
    await h.prefs.setBool('water_reminder_prompt_shown', true);

    await tester.tap(find.byKey(const ValueKey('water-glass-0')));
    await tester.pumpAndSettle();

    expect(find.text('Gerideysen hatırlatayım mı?'), findsNothing);
  });

  testWidgets('soru aksiyonu izin ister ve hatirlatmayi kurar', (tester) async {
    final h = await pumpWaterWidget(tester, const WaterCard());

    await tester.tap(find.byKey(const ValueKey('water-glass-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    verify(() => h.notifications.requestPermission()).called(1);
    expect(h.prefs.getBool('water_reminder_enabled'), isTrue);
  });

  testWidgets('eksi bir bardak geri alir', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());
    await tester.tap(find.byKey(const ValueKey('water-glass-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bir bardak çıkar'));
    await tester.pumpAndSettle();

    expect(find.text('0 / 10 bardak'), findsOneWidget);
  });

  testWidgets('son dolu bardaga dokunmak onu geri alir', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());
    await tester.tap(find.byKey(const ValueKey('water-glass-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('water-glass-9')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('water-glass-0')));
    await tester.pumpAndSettle();

    expect(find.text('0 / 10 bardak'), findsOneWidget);
  });

  testWidgets('hedef asilinca bir bos bardak daha eklenir', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WaterCard)),
    );
    await container.read(waterControllerProvider).setGoal(1, (
      title: 't',
      body: 'b',
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('water-glass-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('water-glass-0')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('water-glass-1')), findsOneWidget);
  });

  group('+1 bardak butonu', () {
    Finder button() => find.widgetWithText(FilledButton, '+1 bardak');

    testWidgets('bir bardak ekler, kaynagi card_button', (tester) async {
      await pumpWaterWidget(tester, const WaterCard());

      await tester.tap(button());
      await tester.pumpAndSettle();

      expect(find.text('1 / 10 bardak'), findsOneWidget);
      final analytics =
          ProviderScope.containerOf(
                tester.element(find.byType(WaterCard)),
              ).read(analyticsServiceProvider)
              as RecordingAnalytics;
      expect(analytics.props[FunnelEvents.waterGlassAdded], {
        'source': 'card_button',
      });
    });

    testWidgets('hedef asilinca da ekler', (tester) async {
      await pumpWaterWidget(tester, const WaterCard());
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WaterCard)),
      );
      await container.read(waterControllerProvider).setGoal(1, (
        title: 't',
        body: 'b',
      ));
      await tester.pumpAndSettle();

      await tester.tap(button());
      await tester.pumpAndSettle();
      await tester.tap(button());
      await tester.pumpAndSettle();

      expect(find.text('2 / 1 bardak'), findsOneWidget);
    });

    // The card's own onTap pushes the water route; the harness has no
    // GoRouter, so if the tap leaked to the card this would throw.
    testWidgets('su ekranini acmaz', (tester) async {
      await pumpWaterWidget(tester, const WaterCard());

      await tester.tap(button());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WaterCard), findsOneWidget);
    });

    testWidgets('ilk bardakta hatirlatma sorusu cikar', (tester) async {
      await pumpWaterWidget(tester, const WaterCard());

      await tester.tap(button());
      await tester.pumpAndSettle();

      expect(find.text('Gerideysen hatırlatayım mı?'), findsOneWidget);
    });
  });

  testWidgets('hedefe ulasinca mesaj gorunur', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WaterCard)),
    );
    await container.read(waterControllerProvider).setGoal(1, (
      title: 't',
      body: 'b',
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('water-glass-0')));
    await tester.pumpAndSettle();

    expect(find.text('Günlük hedefe ulaştın'), findsOneWidget);
  });
}
