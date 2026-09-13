import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 10 bardak'), findsOneWidget);
    expect(find.text('2 saatte bir hatırlatayım mı?'), findsOneWidget);
  });

  testWidgets('soru ikinci bardakta tekrar cikmaz', (tester) async {
    final h = await pumpWaterWidget(tester, const WaterCard());
    await h.prefs.setBool('water_reminder_prompt_shown', true);

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    expect(find.text('2 saatte bir hatırlatayım mı?'), findsNothing);
  });

  testWidgets('soru aksiyonu izin ister ve hatirlatmayi kurar', (tester) async {
    final h = await pumpWaterWidget(tester, const WaterCard());

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    verify(() => h.notifications.requestPermission()).called(1);
    expect(h.prefs.getBool('water_reminder_enabled'), isTrue);
  });

  testWidgets('eksi bir bardak geri alir', (tester) async {
    await pumpWaterWidget(tester, const WaterCard());
    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bir bardak çıkar'));
    await tester.pumpAndSettle();

    expect(find.text('0 / 10 bardak'), findsOneWidget);
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

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    expect(find.text('Günlük hedefe ulaştın'), findsOneWidget);
  });
}
