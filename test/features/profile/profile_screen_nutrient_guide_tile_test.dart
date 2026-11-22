// Besin Rehberi girişi: profil ekranındaki kart görünür ve /nutrients
// route'una gider.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutrilens/config/router/route_names.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/features/profile/presentation/screens/profile_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    PackageInfo.setMockInitialValues(
      appName: 'NutriLens',
      packageName: 'app.nutrilens',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
  });

  testWidgets('profile shows the Besin Rehberi card and opens /nutrients', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: '/nutrients',
          name: RouteNames.nutrientGuide,
          builder: (_, _) => const Scaffold(body: Text('NUTRIENT GUIDE')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
          isPremiumProvider.overrideWithValue(false),
          effectiveUserIdProvider.overrideWithValue(null),
        ].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('tr'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Besin Rehberi'), findsOneWidget);

    await tester.tap(find.text('Besin Rehberi'));
    await tester.pumpAndSettle();

    expect(find.text('NUTRIENT GUIDE'), findsOneWidget);
  });
}
