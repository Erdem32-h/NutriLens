import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/core/widgets/scanning_photo.dart';

/// 1x1 saydam PNG — testin görsel çözmeye değil animasyona odaklanması için.
final Uint8List _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQ'
  'GAhKmMIQAAAABJRU5ErkJggg==',
);

Future<void> _pump(WidgetTester tester, {int? sweeps}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: 240,
          height: 135,
          child: ScanningPhoto(image: MemoryImage(_pixel), sweeps: sweeps),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('sinirli supurme yerlesir, pumpAndSettle kilitlenmez', (
    tester,
  ) async {
    // Onboarding bunu sonlu bir degerle cagirir. Sonsuz olsaydi
    // pumpAndSettle asla donmez ve onboarding testleri timeout'a duserdi.
    await _pump(tester, sweeps: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('supurme bitince tarama cizgisi kaldirilir', (tester) async {
    await _pump(tester, sweeps: 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('scan-line')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-line')), findsNothing);
  });

  testWidgets('sweeps null iken animasyon surer', (tester) async {
    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('scan-line')), findsOneWidget);

    // Sonsuz mod: birkac saniye sonra hala tarıyor olmali.
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('scan-line')), findsOneWidget);
  });
}
