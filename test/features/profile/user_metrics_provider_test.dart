import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';
import 'package:nutrilens/features/profile/presentation/providers/user_metrics_provider.dart';

void main() {
  UserMetricsEntity metrics({String userId = 'user-1'}) => UserMetricsEntity(
    userId: userId,
    sex: BiologicalSex.male,
    birthYear: 1990,
    heightCm: 180,
    weightKg: 80,
    activity: ActivityLevel.active,
    updatedAt: DateTime(2026, 8, 14),
  );

  group('dailyCalorieTargetProvider', () {
    test('metrics yoksa varsayilan 2000 doner', () async {
      final container = ProviderContainer(
        overrides: [userMetricsProvider.overrideWith((ref) async => null)],
      );
      addTearDown(container.dispose);

      await container.read(userMetricsProvider.future);

      expect(container.read(dailyCalorieTargetProvider), kDefaultDailyCalories);
    });

    test(
      'yukleniyor durumunda varsayilan 2000 doner (sifir veya null degil)',
      () async {
        final completer = Completer<UserMetricsEntity?>();
        final container = ProviderContainer(
          overrides: [
            userMetricsProvider.overrideWith((ref) => completer.future),
          ],
        );
        addTearDown(container.dispose);

        // userMetricsProvider henuz cozulmedi (AsyncLoading) — okuma bunu
        // tetikler ama .future'i beklemiyoruz.
        final target = container.read(dailyCalorieTargetProvider);

        expect(target, kDefaultDailyCalories);
        expect(target, isNot(0));

        // Temizlik: asili kalan future'i cozup testi kapat.
        completer.complete(null);
        await container.read(userMetricsProvider.future);
      },
    );

    test(
      'hata durumunda istisna sizmadan varsayilan 2000 doner',
      () async {
        final container = ProviderContainer(
          // Riverpod 3 varsayilani hata basina 10'a kadar exponential-backoff
          // retry deniyor (bkz. ProviderContainer.defaultRetry) — bu da testi
          // 30 saniyelik zaman asimina sokar. Test amaci hatanin state'e
          // yansimasi, otomatik iyilesme degil; bu container icin kapatiyoruz.
          retry: (retryCount, error) => null,
          overrides: [
            userMetricsProvider.overrideWith((ref) async {
              throw Exception('boom');
            }),
          ],
        );
        addTearDown(container.dispose);

        // Future'in AsyncError'a cozulmesini bekle; hata burada yutuluyor —
        // asil iddia asagida dailyCalorieTargetProvider'in fircalanmamasi.
        await container.read(userMetricsProvider.future).catchError((_) => null);

        expect(
          () => container.read(dailyCalorieTargetProvider),
          returnsNormally,
        );
        expect(container.read(dailyCalorieTargetProvider), kDefaultDailyCalories);
      },
    );

    test('metrics varsa hesaplayicinin sonucuyla ayni deger doner', () async {
      final m = metrics();
      final container = ProviderContainer(
        overrides: [
          userMetricsProvider.overrideWith((ref) async => m),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userMetricsProvider.future);

      final expected = calculateCalorieTarget(
        m.toCalculatorInput(DateTime.now()),
      ).target;

      expect(container.read(dailyCalorieTargetProvider), expected);
      expect(expected, isNot(kDefaultDailyCalories));
    });
  });
}
