import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/product/presentation/providers/compare_hint_provider.dart';
import 'package:nutrilens/features/product/presentation/widgets/compare_hint_strip.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrap({SharedPreferences? prefs}) => ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        // context.colors, AppColorsExtension'sız temada debug assert
        // fırlatır (app_colors.dart:311-320) — theme şart.
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('tr'),
        home: const Scaffold(body: CompareHintStrip()),
      ),
    );

void main() {
  testWidgets('taze kurulumda görünür; X flag yazar ve şeridi gizler',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(wrap(prefs: prefs));
    await tester.pumpAndSettle();
    expect(
      find.text(
          'İpucu: İki ürünü yan yana kıyaslayabilirsin — ALTERNATİF sekmesine bak.'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(prefs.getBool(kCompareHintDismissedKey), isTrue);
  });

  testWidgets('flag daha önce yazılmışsa hiç render olmaz', (tester) async {
    SharedPreferences.setMockInitialValues({kCompareHintDismissedKey: true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(wrap(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.byIcon(Icons.compare_arrows_rounded), findsNothing);
  });

  testWidgets('prefs erişilemezse hiç render olmaz (savunmacı)',
      (tester) async {
    // Override yok → sharedPreferencesProvider UnimplementedError fırlatır,
    // provider bunu yakalayıp true (gizli) döner.
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
}
