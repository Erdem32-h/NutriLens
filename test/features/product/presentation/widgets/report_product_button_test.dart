import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/product/data/datasources/community_product_source.dart';
import 'package:nutrilens/features/product/presentation/widgets/report_product_button.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

Widget wrap({
  required Future<ReportOutcome> Function() onReport,
  Future<bool> Function()? canProceed,
}) =>
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            ReportProductButton(
              canProceed: canProceed ?? () async => true,
              onReport: onReport,
            ),
          ],
        ),
      ),
    );

Future<void> tapReportAndConfirm(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.flag_outlined));
  await tester.pumpAndSettle();
  expect(find.text('Bu ürünü bildir'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, 'Bildir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onaylanınca bildirir ve teşekkür eder', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(onReport: () async {
      calls++;
      return ReportOutcome.reported;
    }));

    await tapReportAndConfirm(tester);

    expect(calls, 1);
    expect(find.text('Teşekkürler, bildirimin alındı.'), findsOneWidget);
  });

  testWidgets('vazgeçilirse bildirim gönderilmez', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(onReport: () async {
      calls++;
      return ReportOutcome.reported;
    }));

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('giriş kapısı geçilmezse diyalog açılmaz', (tester) async {
    var calls = 0;
    await tester.pumpWidget(wrap(
      canProceed: () async => false,
      onReport: () async {
        calls++;
        return ReportOutcome.reported;
      },
    ));

    await tester.tap(find.byIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Bu ürünü bildir'), findsNothing);
    expect(calls, 0);
  });

  testWidgets('tekrar bildirimde "zaten bildirmiştin" der', (tester) async {
    await tester.pumpWidget(
        wrap(onReport: () async => ReportOutcome.alreadyReported));
    await tapReportAndConfirm(tester);
    expect(find.text('Bu ürünü zaten bildirmiştin.'), findsOneWidget);
  });

  testWidgets('topluluk kaydı yoksa destek sayfasına yönlendirir',
      (tester) async {
    await tester.pumpWidget(wrap(onReport: () async => ReportOutcome.notFound));
    await tapReportAndConfirm(tester);
    expect(find.textContaining('destek sayfamızdan'), findsOneWidget);
  });

  testWidgets('hata olursa kullanıcıya tekrar dene der', (tester) async {
    await tester.pumpWidget(
        wrap(onReport: () async => throw Exception('network down')));
    await tapReportAndConfirm(tester);
    expect(find.text('Bildirim gönderilemedi. Lütfen tekrar dene.'),
        findsOneWidget);
  });
}
