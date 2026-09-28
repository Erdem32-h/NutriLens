import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/session/guest_migration_service.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/auth/presentation/widgets/guest_migration_prompt_sheet.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

Future<void> _pump(WidgetTester tester, GuestDataSummary summary) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: GuestMigrationPromptSheet(summary: summary)),
    ),
  );
}

void main() {
  testWidgets('yalniz oruc kaydi olan misafir: oruc gunleri satirda', (
    tester,
  ) async {
    await _pump(
      tester,
      const GuestDataSummary(
        scanCount: 0,
        mealCount: 0,
        hasMetrics: false,
        fastingDayCount: 5,
      ),
    );

    expect(
      find.text(
        'Bu cihazda 5 günlük oruç kaydı bulunuyor. '
        'Bunları yeni hesabına yükleyelim mi?',
      ),
      findsOneWidget,
    );
  });

  testWidgets('tamamlanmis oruc kaydi olan misafir: oruc sayisi satirda', (
    tester,
  ) async {
    await _pump(
      tester,
      const GuestDataSummary(
        scanCount: 0,
        mealCount: 0,
        hasMetrics: false,
        completedFastCount: 3,
      ),
    );

    expect(
      find.text('Bu cihazda 3 oruç bulunuyor. Bunları yeni hesabına yükleyelim mi?'),
      findsOneWidget,
    );
  });

  testWidgets('yalniz olculeri olan misafir: genel metin, bos satir yok', (
    tester,
  ) async {
    await _pump(
      tester,
      const GuestDataSummary(scanCount: 0, mealCount: 0, hasMetrics: true),
    );

    expect(
      find.text('Bu cihazda kayıtlı verilerin var. Yeni hesabına taşıyalım mı?'),
      findsOneWidget,
    );
    expect(find.textContaining('Bu cihazda  bulunuyor'), findsNothing);
  });
}
