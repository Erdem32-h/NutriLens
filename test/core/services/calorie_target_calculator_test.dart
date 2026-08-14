import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/calorie_target_calculator.dart';

void main() {
  group('calculateCalorieTarget', () {
    test('Mifflin-St Jeor erkek referans değeri', () {
      // 80 kg, 180 cm, 30 yaş, erkek:
      // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
      final r = calculateCalorieTarget(
        const CalorieTargetInput(
          sex: BiologicalSex.male,
          age: 30,
          heightCm: 180,
          weightKg: 80,
          activity: ActivityLevel.sedentary,
        ),
      );
      expect(r.bmr, 1780);
      expect(r.tdee, 2140); // 1780 * 1.2 = 2136 → 10'a yuvarlanır
      expect(r.target, 2140); // hedef kilo yok → koruma
    });

    test('Mifflin-St Jeor kadın referans değeri', () {
      // 60 kg, 165 cm, 30 yaş, kadın:
      // 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25
      final r = calculateCalorieTarget(
        const CalorieTargetInput(
          sex: BiologicalSex.female,
          age: 30,
          heightCm: 165,
          weightKg: 60,
          activity: ActivityLevel.moderate,
        ),
      );
      expect(r.bmr, 1320);
      expect(r.tdee, 2050); // 1320.25 * 1.55 = 2046.4 → 2050
    });

    test('belirtilmemiş cinsiyet iki formülün ortasını kullanır', () {
      const base = CalorieTargetInput(
        sex: BiologicalSex.unspecified,
        age: 30,
        heightCm: 180,
        weightKg: 80,
        activity: ActivityLevel.sedentary,
      );
      final r = calculateCalorieTarget(base);
      // 10*80 + 6.25*180 - 5*30 - 78 = 1697.0, _round10 → 1700
      expect(r.bmr, 1700);
    });

    test('hedef kilo düşükse %15 açık uygulanır', () {
      final r = calculateCalorieTarget(
        const CalorieTargetInput(
          sex: BiologicalSex.male,
          age: 30,
          heightCm: 180,
          weightKg: 90,
          targetWeightKg: 80,
          activity: ActivityLevel.moderate,
        ),
      );
      expect(r.target, lessThan(r.tdee));
      expect(r.target, (r.tdee * 0.85 / 10).round() * 10);
    });

    test('hedef kilo yüksekse %10 fazla uygulanır', () {
      final r = calculateCalorieTarget(
        const CalorieTargetInput(
          sex: BiologicalSex.male,
          age: 30,
          heightCm: 180,
          weightKg: 60,
          targetWeightKg: 70,
          activity: ActivityLevel.moderate,
        ),
      );
      expect(r.target, greaterThan(r.tdee));
    });

    test('hedef mevcut kiloya 1 kg mesafedeyse koruma sayılır', () {
      final r = calculateCalorieTarget(
        const CalorieTargetInput(
          sex: BiologicalSex.female,
          age: 40,
          heightCm: 170,
          weightKg: 70,
          targetWeightKg: 69.5,
          activity: ActivityLevel.light,
        ),
      );
      expect(r.target, r.tdee);
    });

    test('hedef asla BMR ve 1200 tabanının altına inmez', () {
      // Küçük, hareketsiz, agresif hedefli kullanıcı
      final r = calculateCalorieTarget(
        const CalorieTargetInput(
          sex: BiologicalSex.female,
          age: 60,
          heightCm: 150,
          weightKg: 50,
          targetWeightKg: 40,
          activity: ActivityLevel.sedentary,
        ),
      );
      expect(r.target, greaterThanOrEqualTo(1200));
      expect(r.target, greaterThanOrEqualTo(r.bmr));
    });

    test('sınır dışı girdiler kırpılır, doğru sonuç verir', () {
      // Kırpma sınırları: yaş 16–100, boy 120–230, kilo 30–300
      // Girdiler: age 5, height 400, weight 500, targetWeight 50 (tümü sınır dışı)
      // Beklenen kırpma: age→16, height→230, weight→300, targetWeight→30
      final r = calculateCalorieTarget(
        const CalorieTargetInput(
          sex: BiologicalSex.male,
          age: 5,
          heightCm: 400,
          weightKg: 500,
          targetWeightKg: 50,
          activity: ActivityLevel.active,
        ),
      );

      // Kırpılmış: 10*300 + 6.25*230 - 5*16 + 5 = 4362.5 → 4360
      expect(r.bmr, 4360);

      // TDEE = 4362.5 * 1.725 = 7527.1875 → 7530
      expect(r.tdee, 7530);

      // target=30 < weight=300-1 → %85 açık: 7530*0.85 = 6400.5 → 6400
      expect(r.target, 6400);
      expect(r.target, lessThan(r.tdee)); // açık uygulandı
    });

    test('aktivite faktörleri beklenen sırada', () {
      expect(ActivityLevel.sedentary.factor, 1.2);
      expect(ActivityLevel.light.factor, 1.375);
      expect(ActivityLevel.moderate.factor, 1.55);
      expect(ActivityLevel.active.factor, 1.725);
    });
  });
}
