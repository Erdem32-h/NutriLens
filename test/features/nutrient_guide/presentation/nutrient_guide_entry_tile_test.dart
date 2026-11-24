import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nutrilens/config/router/route_names.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/nutrient_guide/presentation/widgets/nutrient_guide_entry_tile.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

Widget _app(Widget tile) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: tile)),
      GoRoute(
        path: '/nutrients',
        name: RouteNames.nutrientGuide,
        builder: (_, state) =>
            Text('GUIDE tab=${state.uri.queryParameters['tab']}'),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light,
    locale: const Locale('tr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  testWidgets('opens the guide with no tab', (t) async {
    await t.pumpWidget(_app(const NutrientGuideEntryTile()));
    await t.pumpAndSettle();

    expect(find.text('Besin Rehberi'), findsOneWidget);
    await t.tap(find.text('Besin Rehberi'));
    await t.pumpAndSettle();
    expect(find.text('GUIDE tab=null'), findsOneWidget);
  });

  testWidgets('passes the requested tab', (t) async {
    await t.pumpWidget(_app(const NutrientGuideEntryTile(tab: 'amino')));
    await t.pumpAndSettle();

    await t.tap(find.text('Besin Rehberi'));
    await t.pumpAndSettle();
    expect(find.text('GUIDE tab=amino'), findsOneWidget);
  });
}
