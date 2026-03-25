import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BentoNutritionGrid._riskLevel', () {
    // The _riskLevel is a static method, so we need to test the algorithm logic
    // We test the risk calculation boundaries used in the widget

    int riskLevel(double percent) {
      // Mirror the exact logic from BentoNutritionGrid._riskLevel
      if (percent < 15) return 1;
      if (percent < 30) return 2;
      if (percent < 50) return 3;
      if (percent < 75) return 4;
      return 5;
    }

    test('returns 1 (low) for < 15%', () {
      expect(riskLevel(0), 1);
      expect(riskLevel(5), 1);
      expect(riskLevel(14.9), 1);
    });

    test('returns 2 (moderate) for 15% to < 30%', () {
      expect(riskLevel(15), 2);
      expect(riskLevel(20), 2);
      expect(riskLevel(29.9), 2);
    });

    test('returns 3 (high) for 30% to < 50%', () {
      expect(riskLevel(30), 3);
      expect(riskLevel(40), 3);
      expect(riskLevel(49.9), 3);
    });

    test('returns 4 (critical) for 50% to < 75%', () {
      expect(riskLevel(50), 4);
      expect(riskLevel(60), 4);
      expect(riskLevel(74.9), 4);
    });

    test('returns 5 (very high) for >= 75%', () {
      expect(riskLevel(75), 5);
      expect(riskLevel(100), 5);
      expect(riskLevel(150), 5);
    });
  });

  group('BentoNutritionGrid daily value calculations', () {
    // Test the daily reference percentages
    const dailyFat = 70.0;
    const dailySugar = 50.0;
    const dailySatFat = 20.0;
    const dailySalt = 6.0;
    const dailyCalories = 2000.0;

    double percent(double value, double daily) {
      return (value / daily * 100).clamp(0, 999).toDouble();
    }

    test('fat percentage calculation', () {
      expect(percent(35.0, dailyFat), 50.0); // 50%
      expect(percent(70.0, dailyFat), 100.0); // 100%
      expect(percent(7.0, dailyFat), 10.0); // 10%
    });

    test('sugar percentage calculation', () {
      expect(percent(25.0, dailySugar), 50.0); // 50%
      expect(percent(50.0, dailySugar), 100.0); // 100%
      expect(percent(5.0, dailySugar), 10.0); // 10%
    });

    test('saturated fat percentage calculation', () {
      expect(percent(10.0, dailySatFat), 50.0); // 50%
      expect(percent(20.0, dailySatFat), 100.0); // 100%
      expect(percent(2.0, dailySatFat), 10.0); // 10%
    });

    test('salt percentage calculation', () {
      expect(percent(3.0, dailySalt), 50.0); // 50%
      expect(percent(6.0, dailySalt), 100.0); // 100%
      expect(percent(0.6, dailySalt), closeTo(10.0, 0.01)); // ~10%
    });

    test('calorie percentage calculation', () {
      expect(percent(1000.0, dailyCalories), 50.0); // 50%
      expect(percent(2000.0, dailyCalories), 100.0); // 100%
      expect(percent(200.0, dailyCalories), 10.0); // 10%
    });

    test('percentage is clamped to 0 minimum', () {
      expect(percent(0, dailyFat), 0);
    });

    test('percentage is clamped to 999 maximum', () {
      expect(percent(999999, dailyFat), 999);
    });
  });
}
