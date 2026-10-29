import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/core/utils/gs1_digital_link.dart';
import 'package:nutrilens/features/product/presentation/widgets/digital_link_card.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

Widget wrap(Gs1DigitalLink link, {DateTime? now}) => MaterialApp(
      // context.colors, AppColorsExtension'sız temada debug assert fırlatır.
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      home: Scaffold(
        body: DigitalLinkCard(link: link, now: now == null ? null : () => now),
      ),
    );

void main() {
  final full = Gs1DigitalLink.tryParse(
      'https://x.io/01/08690504000013/10/LOT%2042?17=271231')!;

  testWidgets('parti, SKT ve üretici butonu görünür', (tester) async {
    await tester.pumpWidget(wrap(full, now: DateTime(2026, 10, 29)));
    expect(find.text('Parti: LOT 42'), findsOneWidget);
    expect(find.text('SKT: 31.12.2027'), findsOneWidget);
    expect(find.text('Üretici sayfası'), findsOneWidget);
    expect(find.text('x.io'), findsOneWidget);
    expect(find.text('Süresi geçmiş'), findsNothing);
  });

  testWidgets('SKT geçmişse uyarı gösterir', (tester) async {
    await tester.pumpWidget(wrap(full, now: DateTime(2028, 1, 1)));
    expect(find.text('Süresi geçmiş'), findsOneWidget);
  });

  testWidgets('SKT günü içinde hâlâ geçerli', (tester) async {
    await tester.pumpWidget(wrap(full, now: DateTime(2027, 12, 31, 18)));
    expect(find.text('Süresi geçmiş'), findsNothing);
  });

  testWidgets('parti/SKT yoksa yalnız üretici butonu', (tester) async {
    final bare = Gs1DigitalLink.tryParse('https://x.io/01/08690504000013')!;
    await tester.pumpWidget(wrap(bare));
    expect(find.textContaining('Parti'), findsNothing);
    expect(find.textContaining('SKT'), findsNothing);
    expect(find.text('Üretici sayfası'), findsOneWidget);
  });
}
