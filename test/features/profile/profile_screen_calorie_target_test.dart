// Regresyon testi: profile_screen.dart'taki kişisel kalori hedefi kartı,
// hedef gerçekten hesaplanmışken (personalTarget != null)
// `metricsMedicalDisclaimer` dipnotunu göstermeli — spec'in Global
// Constraints bölümü bu dipnotu her sonuç/özet yüzeyinde zorunlu kılıyor,
// ama sihirbazın kendi sonuç sayfası dışında hiçbir yüzey bunu taşımıyordu.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/providers/locale_provider.dart';
import 'package:nutrilens/core/providers/monetization_provider.dart';
import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/core/session/app_session.dart';
import 'package:nutrilens/core/theme/app_theme.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';
import 'package:nutrilens/features/profile/data/datasources/user_metrics_local_datasource.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';
import 'package:nutrilens/features/product/presentation/providers/product_provider.dart';
import 'package:nutrilens/features/profile/presentation/screens/profile_screen.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

const _disclaimer = 'Tahmini değerdir, tıbbi tavsiye yerine geçmez.';

Widget _wrap(
  Widget child, {
  required SharedPreferences prefs,
  List extraOverrides = const [],
}) =>
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(null),
        isPremiumProvider.overrideWithValue(false),
        ...extraOverrides,
      ].cast(),
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('tr'),
        home: child,
      ),
    );

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // PackageInfo.fromPlatform() olmadan _VersionFooter Windows'ta
    // sonsuza dek asilabilir (bkz. onboarding_screen_test.dart ayni
    // yorum) — build'i engellemiyor ama pumpAndSettle'i asabilir.
    PackageInfo.setMockInitialValues(
      appName: 'NutriLens',
      packageName: 'app.nutrilens',
      version: '0.0.0',
      buildNumber: '0',
      buildSignature: '',
    );
  });

  testWidgets(
    'hedef henuz hesaplanmamisken (metrics yok) davet metni gorunur, '
    'tibbi tavsiye dipnotu gorunmez',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProfileScreen(),
          prefs: prefs,
          extraOverrides: [effectiveUserIdProvider.overrideWithValue(null)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kişisel kalori hedefini hesapla'), findsOneWidget);
      expect(find.textContaining(_disclaimer), findsNothing);
    },
  );

  testWidgets(
    'hedef hesaplanmisken (metrics var) kart tibbi tavsiye dipnotunu '
    'gosterir',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await UserMetricsLocalDataSourceImpl(db).save(
        UserMetricsEntity(
          userId: 'user-1',
          sex: BiologicalSex.female,
          birthYear: 1990,
          heightCm: 165,
          weightKg: 60,
          activity: ActivityLevel.moderate,
          updatedAt: DateTime(2026, 8, 14),
        ),
      );

      await tester.pumpWidget(
        _wrap(
          const ProfileScreen(),
          prefs: prefs,
          extraOverrides: [
            appDatabaseProvider.overrideWithValue(db),
            effectiveUserIdProvider.overrideWithValue('user-1'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Günlük hedefin'), findsOneWidget);
      expect(
        find.textContaining(_disclaimer),
        findsOneWidget,
        reason:
            'gercek bir hedef gosterilirken (kisisel ya da varsayilan '
            'degil) tibbi tavsiye dipnotu her zaman gorunmeli',
      );
    },
  );
}
