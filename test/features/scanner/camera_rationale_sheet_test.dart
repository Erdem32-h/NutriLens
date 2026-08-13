import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_colors.dart';
import 'package:nutrilens/features/scanner/presentation/widgets/camera_rationale_sheet.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

/// Opens the sheet from a real route and records what it returned.
Future<bool?> _showAndTap(WidgetTester tester, String buttonText) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(extensions: const [AppColorsExtension.light]),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await CameraRationaleSheet.show(context);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(buttonText));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  group('CameraRationaleSheet', () {
    testWidgets('continuing returns true so the caller starts the camera', (
      tester,
    ) async {
      expect(await _showAndTap(tester, 'Devam et'), isTrue);
    });

    testWidgets('declining returns false — the OS prompt is never spent', (
      tester,
    ) async {
      // The whole point of the sheet: a "not now" must not fall through to
      // the system dialog, because Android stops offering it after a denial.
      expect(await _showAndTap(tester, 'Şimdi değil'), isFalse);
    });

    testWidgets('explains why the camera is wanted before it is asked for', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(extensions: const [AppColorsExtension.light]),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => CameraRationaleSheet.show(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Kamera izni gerekiyor'), findsOneWidget);
      // Both scanner modes share this sheet, so the copy has to cover the
      // barcode path as well as the plate photo.
      expect(find.textContaining('barkodunu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
