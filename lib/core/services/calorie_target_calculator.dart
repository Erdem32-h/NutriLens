/// Günlük kalori hedefi hesaplayıcısı.
///
/// Saf fonksiyon: I/O, provider veya Flutter bağımlılığı yok. Hem birim
/// testleri hem UI aynı fonksiyonu çağırır, böylece "ekranda gösterilen
/// sayı" ile "test edilen sayı" ayrışamaz.
///
/// Formül Mifflin-St Jeor (1990) — Harris-Benedict'e göre modern
/// popülasyonlarda daha doğru kabul edilir ve klinik dışı uygulamalarda
/// fiilî standarttır.
library;

/// Metrics girilmemiş kullanıcı için düşülen referans. Besin etiketlerinin
/// klasik "2000 kcal'lik yetişkin diyeti" varsayımı.
const int kDefaultDailyCalories = 2000;

const int _minAge = 16;
const int _maxAge = 100;
const int _minHeightCm = 120;
const int _maxHeightCm = 230;
const double _minWeightKg = 30;
const double _maxWeightKg = 300;

/// Mutlak alt taban. BMR bunun altındaysa bile hedef buraya çekilir.
const int _absoluteFloorKcal = 1200;

enum BiologicalSex { male, female, unspecified }

enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active;

  double get factor => switch (this) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.light => 1.375,
    ActivityLevel.moderate => 1.55,
    ActivityLevel.active => 1.725,
  };
}

class CalorieTargetInput {
  final BiologicalSex sex;
  final int age;
  final int heightCm;
  final double weightKg;

  /// null → koruma (TDEE). Kullanıcı "kilomu korumak istiyorum" derse.
  final double? targetWeightKg;
  final ActivityLevel activity;

  const CalorieTargetInput({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    this.targetWeightKg,
    required this.activity,
  });
}

class CalorieTargetResult {
  /// Bazal metabolizma hızı — hiç hareket etmeden yakılan.
  final int bmr;

  /// BMR × aktivite faktörü — kiloyu koruyan değer.
  final int tdee;

  /// Hedefe göre ayarlanmış ve tabana çekilmiş nihai günlük hedef.
  final int target;

  const CalorieTargetResult({
    required this.bmr,
    required this.tdee,
    required this.target,
  });
}

CalorieTargetResult calculateCalorieTarget(CalorieTargetInput input) {
  // Savunmacı kırpma: form katmanı zaten doğruluyor, ama bozuk bir kayıt
  // (eski sürümden gelen, elle düzenlenmiş DB) hesabı saçmalatmasın.
  final age = input.age.clamp(_minAge, _maxAge);
  final heightCm = input.heightCm.clamp(_minHeightCm, _maxHeightCm);
  final weightKg = input.weightKg.clamp(_minWeightKg, _maxWeightKg);

  final sexOffset = switch (input.sex) {
    BiologicalSex.male => 5.0,
    BiologicalSex.female => -161.0,
    // İki sabitin ortalaması: (5 + (-161)) / 2 = -78.
    BiologicalSex.unspecified => -78.0,
  };

  final bmrRaw = 10 * weightKg + 6.25 * heightCm - 5 * age + sexOffset;
  final tdeeRaw = bmrRaw * input.activity.factor;
  final bmrRounded = _round10(bmrRaw);
  final tdeeRounded = _round10(tdeeRaw);

  final target = input.targetWeightKg;
  double adjusted = tdeeRounded.toDouble();
  if (target != null) {
    final clampedTarget = target.clamp(_minWeightKg, _maxWeightKg);
    if (clampedTarget < weightKg - 1) {
      adjusted = tdeeRounded * 0.85;
    } else if (clampedTarget > weightKg + 1) {
      adjusted = tdeeRounded * 1.10;
    }
  }

  // Taban: BMR'nin altında kalıcı bir açık sağlıklı değil; 1200 de mutlak
  // alt sınır. İkisinin büyüğü kazanır.
  final floor = bmrRaw > _absoluteFloorKcal ? bmrRaw : _absoluteFloorKcal.toDouble();
  final floored = adjusted < floor ? floor : adjusted;

  return CalorieTargetResult(
    bmr: bmrRounded,
    tdee: tdeeRounded,
    target: _round10(floored),
  );
}

/// Kullanıcıya "2 137 kcal" göstermek sahte bir hassasiyet iddiası —
/// tahminin hata payı zaten ±%10. 10'a yuvarlıyoruz.
int _round10(double value) => (value / 10).round() * 10;
