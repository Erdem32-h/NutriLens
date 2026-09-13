import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/water/presentation/providers/water_provider.dart';
import 'package:nutrilens/features/water/presentation/screens/water_screen.dart';

import 'water_widget_harness.dart';

Finder _bars() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('water-bar-'),
);

void main() {
  testWidgets('7 gunluk grafik ve varsayilan hedef', (tester) async {
    await pumpWaterWidget(tester, const WaterScreen());

    expect(_bars(), findsNWidgets(7));
    expect(find.text('10 bardak (2 L)'), findsOneWidget);
    expect(find.text('Kiloma göre ayarla'), findsNothing);
  });

  testWidgets('hedef artirilinca litre de guncellenir', (tester) async {
    await pumpWaterWidget(tester, const WaterScreen());

    await tester.tap(find.byTooltip('Hedefi artır'));
    await tester.pumpAndSettle();

    expect(find.text('11 bardak (2,2 L)'), findsOneWidget);
  });

  testWidgets('bugun eklenen bardak grafikte son cubuga yansir', (
    tester,
  ) async {
    await pumpWaterWidget(tester, const WaterScreen());

    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('water-bar-2026-09-13')), findsOneWidget);
    expect(find.text('1 / 10 bardak'), findsOneWidget);
  });

  testWidgets('izin reddedilince anahtar kapali kalir ve mesaj cikar', (
    tester,
  ) async {
    await pumpWaterWidget(
      tester,
      const WaterScreen(),
      permissionGranted: false,
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(
      find.text('Bildirim izni verilmedi. Ayarlardan açabilirsin.'),
      findsOneWidget,
    );
  });

  testWidgets('buyuk metin olceginde haftalik grafik tasmaz', (tester) async {
    await pumpWaterWidget(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: const WaterScreen(),
      ),
    );

    // Goal 1 + one glass logged -> today's bar hits its full 90px max
    // height, the worst case the fixed-height chart row has to fit
    // alongside the 2x-scaled labels above and below it.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WaterScreen)),
    );
    await container.read(waterControllerProvider).setGoal(1, (
      title: 't',
      body: 'b',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+1 bardak'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_bars(), findsNWidgets(7));
  });
}
