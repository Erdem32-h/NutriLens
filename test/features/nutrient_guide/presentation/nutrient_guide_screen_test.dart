import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrilens/config/router/route_names.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/nutrient_guide/domain/entities/nutrient_entity.dart';
import 'package:nutrilens/features/nutrient_guide/presentation/providers/nutrient_provider.dart';
import 'package:nutrilens/features/nutrient_guide/presentation/screens/nutrient_guide_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

NutrientEntity _n(
  String id,
  NutrientCategory c,
  String tr,
  String en, {
  AminoAcidClass? amino,
}) {
  const one = Localized<List<String>>(tr: ['x'], en: ['x']);
  return NutrientEntity(
    id: id,
    category: c,
    aminoClass: c == NutrientCategory.aminoAcid
        ? amino ?? AminoAcidClass.essential
        : null,
    name: Localized(tr: tr, en: en),
    altName: null,
    function: const Localized(tr: 'a', en: 'a'),
    deficiency: one,
    excess: one,
    sources: one,
    dailyNeed: '1 mg',
    upperLimit: null,
    source: 'NIH ODS',
  );
}

final _data = [
  _n('vitamin_c', NutrientCategory.vitamin, 'C Vitamini', 'Vitamin C'),
  _n('iodine', NutrientCategory.mineral, 'İyot', 'Iodine'),
  _n('selenium', NutrientCategory.mineral, 'Selenyum', 'Selenium'),
  _n('lysine', NutrientCategory.aminoAcid, 'Lizin', 'Lysine'),
  _n(
    'glycine',
    NutrientCategory.aminoAcid,
    'Glisin',
    'Glycine',
    amino: AminoAcidClass.conditional,
  ),
  _n(
    'alanine',
    NutrientCategory.aminoAcid,
    'Alanin',
    'Alanine',
    amino: AminoAcidClass.nonEssential,
  ),
];

Widget _app({
  required Override provider,
  String locale = 'tr',
  String initialLocation = '/',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => NutrientGuideScreen(
          initialTab: state.uri.queryParameters['tab'],
        ),
      ),
      GoRoute(
        path: '/nutrient/:id',
        name: RouteNames.nutrientDetail,
        builder: (_, state) =>
            Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [provider],
    child: MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light,
      locale: Locale(locale),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

Override _ok() => nutrientsProvider.overrideWith((ref) async => _data);

void main() {
  testWidgets('shows three tabs and the vitamin list by default', (t) async {
    await t.pumpWidget(_app(provider: _ok()));
    await t.pumpAndSettle();

    expect(find.text('Vitaminler'), findsOneWidget);
    expect(find.text('Mineraller'), findsOneWidget);
    expect(find.text('Amino asitler'), findsOneWidget);
    expect(find.text('C Vitamini'), findsOneWidget);
    expect(find.text('İyot'), findsNothing);
  });

  testWidgets('switching to Mineraller shows only minerals', (t) async {
    await t.pumpWidget(_app(provider: _ok()));
    await t.pumpAndSettle();

    await t.tap(find.text('Mineraller'));
    await t.pumpAndSettle();

    expect(find.text('İyot'), findsOneWidget);
    expect(find.text('Selenyum'), findsOneWidget);
    expect(find.text('C Vitamini'), findsNothing);
  });

  testWidgets('typing "iyot" keeps İyot and hides other minerals', (t) async {
    await t.pumpWidget(_app(provider: _ok()));
    await t.pumpAndSettle();
    await t.tap(find.text('Mineraller'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'iyot');
    await t.pumpAndSettle();

    expect(find.text('İyot'), findsOneWidget);
    expect(find.text('Selenyum'), findsNothing);
  });

  testWidgets('no match shows the empty-state message', (t) async {
    await t.pumpWidget(_app(provider: _ok()));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), 'zzz');
    await t.pumpAndSettle();

    expect(find.text('Sonuç bulunamadı'), findsOneWidget);
    expect(find.text('C Vitamini'), findsNothing);
  });

  testWidgets('load error shows retry and recovers after retry', (t) async {
    var calls = 0;
    final provider = nutrientsProvider.overrideWith((ref) async {
      calls++;
      if (calls == 1) throw const FormatException('boom');
      return _data;
    });
    await t.pumpWidget(_app(provider: provider));
    await t.pumpAndSettle();

    expect(find.text('İçerik yüklenemedi'), findsOneWidget);

    await t.tap(find.text('Tekrar dene'));
    await t.pumpAndSettle();

    expect(find.text('C Vitamini'), findsOneWidget);
    expect(find.text('İçerik yüklenemedi'), findsNothing);
  });

  testWidgets('locale ar shows Arabic UI text and falls back to English names', (
    t,
  ) async {
    await t.pumpWidget(_app(provider: _ok(), locale: 'ar'));
    await t.pumpAndSettle();

    expect(find.text('Vitamin C'), findsOneWidget);
    expect(find.text('الفيتامينات'), findsOneWidget);
  });

  testWidgets('tapping a row opens the detail route for that id', (t) async {
    await t.pumpWidget(_app(provider: _ok()));
    await t.pumpAndSettle();

    await t.tap(find.text('C Vitamini'));
    await t.pumpAndSettle();

    expect(find.text('DETAIL vitamin_c'), findsOneWidget);
  });

  testWidgets('amino acid tab groups by essential / conditional / '
      'non-essential with counts', (t) async {
    await t.pumpWidget(_app(provider: _ok()));
    await t.pumpAndSettle();
    await t.tap(find.text('Amino asitler'));
    await t.pumpAndSettle();

    expect(find.text('Temel · besinle alınmalı (1)'), findsOneWidget);
    expect(find.text('Şartlı temel · bazen besinle alınmalı (1)'), findsOneWidget);
    expect(find.text('Temel değil · vücut üretir (1)'), findsOneWidget);
    expect(find.text('Lizin'), findsOneWidget);
    expect(find.text('Glisin'), findsOneWidget);
    expect(find.text('Alanin'), findsOneWidget);
    final lizin = t.getTopLeft(find.text('Lizin')).dy;
    final glisin = t.getTopLeft(find.text('Glisin')).dy;
    final alanin = t.getTopLeft(find.text('Alanin')).dy;
    expect(lizin < glisin && glisin < alanin, isTrue);
  });

  testWidgets('search hides empty amino groups', (t) async {
    await t.pumpWidget(_app(provider: _ok()));
    await t.pumpAndSettle();
    await t.tap(find.text('Amino asitler'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'glis');
    await t.pumpAndSettle();

    expect(find.text('Glisin'), findsOneWidget);
    expect(find.text('Temel · besinle alınmalı (1)'), findsNothing);
    expect(find.text('Şartlı temel · bazen besinle alınmalı (1)'), findsOneWidget);
  });

  testWidgets('?tab=amino opens on the amino acid tab', (t) async {
    await t.pumpWidget(
      _app(provider: _ok(), initialLocation: '/?tab=amino'),
    );
    await t.pumpAndSettle();

    expect(find.text('Lizin'), findsOneWidget);
    expect(find.text('C Vitamini'), findsNothing);
  });
}
