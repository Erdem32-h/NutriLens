import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/nutrient_guide/domain/entities/nutrient_entity.dart';
import 'package:nutrilens/features/nutrient_guide/domain/repositories/nutrient_repository.dart';
import 'package:nutrilens/features/nutrient_guide/presentation/providers/nutrient_provider.dart';
import 'package:nutrilens/features/nutrient_guide/presentation/screens/nutrient_detail_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

NutrientEntity _vitC({String? upperLimit = '2000 mg'}) => NutrientEntity(
  id: 'vitamin_c',
  category: NutrientCategory.vitamin,
  name: const Localized(tr: 'C Vitamini', en: 'Vitamin C'),
  altName: const Localized(tr: 'Askorbik asit', en: 'Ascorbic acid'),
  function: const Localized(
    tr: 'Kolajen yapımına yardımcı olur.',
    en: 'Helps make collagen.',
  ),
  deficiency: const Localized(
    tr: ['Yorgunluk', 'Diş eti kanaması'],
    en: ['Fatigue', 'Bleeding gums'],
  ),
  excess: const Localized(tr: ['Bulantı', 'İshal'], en: ['Nausea', 'Diarrhea']),
  sources: const Localized(tr: ['Biber', 'Kivi'], en: ['Peppers', 'Kiwi']),
  dailyNeed: '75–90 mg',
  upperLimit: upperLimit,
  source: 'NIH ODS',
);

Widget _app(Override provider, {String locale = 'tr', double textScale = 1.0}) {
  return ProviderScope(
    overrides: [provider],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const NutrientDetailScreen(nutrientId: 'vitamin_c'),
    ),
  );
}

Override _returns(NutrientEntity? n) =>
    nutrientByIdProvider.overrideWith((ref, id) async => n);

void _tallScreen(WidgetTester t) {
  t.view.physicalSize = const Size(800, 4000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

class _BrokenRepository implements NutrientRepository {
  @override
  Future<List<NutrientEntity>> getAll() async =>
      throw const FormatException('corrupt asset');
}

void main() {
  testWidgets('renders every section and the disclaimer for tr', (t) async {
    _tallScreen(t);
    await t.pumpWidget(_app(_returns(_vitC())));
    await t.pumpAndSettle();

    expect(find.text('C Vitamini'), findsOneWidget);
    expect(find.text('Askorbik asit'), findsOneWidget);
    expect(find.text('Ne işe yarar'), findsOneWidget);
    expect(find.text('Kolajen yapımına yardımcı olur.'), findsOneWidget);
    expect(find.text('Eksikse'), findsOneWidget);
    expect(find.textContaining('Diş eti kanaması'), findsOneWidget);
    expect(find.text('Fazlaysa'), findsOneWidget);
    expect(find.textContaining('İshal'), findsOneWidget);
    expect(find.text('Nerede bulunur'), findsOneWidget);
    expect(find.textContaining('Kivi'), findsOneWidget);
    expect(find.text('Günlük ihtiyaç (yetişkin)'), findsOneWidget);
    expect(find.text('75–90 mg'), findsOneWidget);
    expect(find.text('Kaynak: NIH ODS'), findsOneWidget);
    expect(find.textContaining('tıbbi tavsiye değildir'), findsOneWidget);
  });

  testWidgets('shows the upper limit when present', (t) async {
    _tallScreen(t);
    await t.pumpWidget(_app(_returns(_vitC())));
    await t.pumpAndSettle();

    expect(find.text('Üst sınır'), findsOneWidget);
    expect(find.text('2000 mg'), findsOneWidget);
  });

  testWidgets('hides the upper limit when absent', (t) async {
    _tallScreen(t);
    await t.pumpWidget(_app(_returns(_vitC(upperLimit: null))));
    await t.pumpAndSettle();

    expect(find.text('Üst sınır'), findsNothing);
  });

  testWidgets('unknown id shows the not-found message', (t) async {
    await t.pumpWidget(_app(_returns(null)));
    await t.pumpAndSettle();

    expect(find.text('Bu besin bulunamadı'), findsOneWidget);
  });

  testWidgets('locale zh renders English text, no empty section titles', (
    t,
  ) async {
    _tallScreen(t);
    await t.pumpWidget(_app(_returns(_vitC()), locale: 'zh'));
    await t.pumpAndSettle();

    expect(find.text('Vitamin C'), findsOneWidget);
    expect(find.text('What it does'), findsOneWidget);
    expect(find.text('If you get too little'), findsOneWidget);
    expect(find.text('If you get too much'), findsOneWidget);
    expect(find.text('Where to find it'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
  });

  testWidgets('scrolls without overflow at textScale 2.0', (t) async {
    await t.pumpWidget(_app(_returns(_vitC()), textScale: 2.0));
    await t.pumpAndSettle();

    await t.scrollUntilVisible(
      find.textContaining('tıbbi tavsiye değildir'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(t.takeException(), isNull);
    expect(find.textContaining('tıbbi tavsiye değildir'), findsOneWidget);
  });

  testWidgets('a corrupt asset shows the load error, not an endless spinner', (
    t,
  ) async {
    await t.pumpWidget(
      _app(nutrientRepositoryProvider.overrideWithValue(_BrokenRepository())),
    );
    await t.pumpAndSettle();

    expect(find.text('İçerik yüklenemedi'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
