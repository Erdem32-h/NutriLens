import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/water/domain/water_day.dart';
import 'package:nutrilens/features/water/domain/water_goal.dart';

void main() {
  group('suggestedWaterGoal', () {
    test('kilo yoksa varsayilan 10 bardak', () {
      expect(suggestedWaterGoal(null), 10);
      expect(suggestedWaterGoal(0), 10);
    });

    test('kilo x 35 ml / 200 ml, en yakin bardaga yuvarlanir', () {
      expect(suggestedWaterGoal(70), 12); // 12.25
      expect(suggestedWaterGoal(60), 11); // 10.5
      expect(suggestedWaterGoal(80), 14);
    });

    test('6-16 bardak araligina sikistirilir', () {
      expect(suggestedWaterGoal(30), 6); // 5.25
      expect(suggestedWaterGoal(120), 16); // 21
    });
  });

  group('waterDayKey', () {
    test('sifir dolgulu yyyy-MM-dd', () {
      expect(waterDayKey(DateTime(2026, 9, 3, 23, 59)), '2026-09-03');
      expect(waterDayKey(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  test('goalMet hedefe esit veya ustunde', () {
    expect(
      const WaterDay(day: 'd', glasses: 9, goalGlasses: 10).goalMet,
      false,
    );
    expect(
      const WaterDay(day: 'd', glasses: 10, goalGlasses: 10).goalMet,
      true,
    );
  });
}
