# Kişiye Özel Kalori Hedefi + Porsiyon-Doğru Besin Tablosu — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanıcının vücut ölçülerinden hesaplanan günlük kalori hedefini uygulamaya yerleştirmek ve öğün besin tablosunun "100g" yalanını gerçek porsiyon gramajıyla değiştirmek.

**Architecture:** Saf bir hesaplayıcı (Mifflin-St Jeor → TDEE → hedef) + Drift'te tek satırlık `user_metrics` tablosu + mevcut `user_profiles` Supabase tablosuna eklenen kolonlar. Besin tablosu widget'ları referans tabanını (`basisLabel` ve günlük kalori) parametre olarak alır; kayıt yoksa bugünkü davranışa (100 g / 2000 kcal) düşer.

**Tech Stack:** Flutter, Riverpod 3, Drift, Supabase, fpdart, flutter_test

**Spec:** `docs/superpowers/specs/2026-08-14-kisisel-kalori-ve-porsiyon-besin-tablosu-design.md`

## Global Constraints

- Drift şema sürümü 3 → **4**. Tek migration, yalnızca ekleme (nullable kolon + yeni tablo). Veri dönüşümü yok.
- `UserMetrics` kaydı **yokken hiçbir ekran bozulmaz**: kalori referansı 2000 kcal, besin tablosu başlığı `100 g`. Bugünkü davranış bit bit korunur.
- Kalori hedefi **asla `max(BMR, 1200)` altına inmez**.
- Girdi sınırları: yaş 16–100, boy 120–230 cm, kilo 30–300 kg, hedef kilo 30–300 kg.
- Aktivite faktörleri: `sedentary` 1.2, `light` 1.375, `moderate` 1.55, `active` 1.725.
- Hedef ayarı: hedef < mevcut − 1 kg → ×0.85; hedef > mevcut + 1 kg → ×1.10; aksi halde ×1.0.
- Yeni kullanıcıya görünen her metin `lib/l10n/app_tr.arb` ve `lib/l10n/app_en.arb`'a eklenir, `context.l10n.<key>` ile okunur. Kodda çıplak Türkçe string yok.
- Her sonuç/özet yüzeyinde tıbbi uyarı: `"Tahmini değerdir, tıbbi tavsiye yerine geçmez."`
- Analytics olayları `AnalyticsEvents` sınıfına `static const` olarak eklenir; `analytics.track(name, props: {...})` ile gönderilir.
- Her task sonunda `flutter analyze --fatal-infos` ve `flutter test` temiz olmalı.
- Commit formatı: `<type>: <description>` (feat/fix/refactor/test/chore).

---

### Task 1: Kalori hedefi hesaplayıcısı

Saf fonksiyon. I/O yok, provider yok, Flutter bağımlılığı yok — bu yüzden önce ve tek başına yazılır.

**Files:**
- Create: `lib/core/services/calorie_target_calculator.dart`
- Test: `test/core/services/calorie_target_calculator_test.dart`

**Interfaces:**
- Consumes: yok
- Produces:
  - `enum BiologicalSex { male, female, unspecified }`
  - `enum ActivityLevel { sedentary, light, moderate, active }` — `double get factor`
  - `class CalorieTargetInput { BiologicalSex sex; int age; int heightCm; double weightKg; double? targetWeightKg; ActivityLevel activity; }`
  - `class CalorieTargetResult { int bmr; int tdee; int target; }`
  - `CalorieTargetResult calculateCalorieTarget(CalorieTargetInput input)`
  - `const int kDefaultDailyCalories = 2000;`

- [ ] **Step 1: Write the failing test**

`test/core/services/calorie_target_calculator_test.dart`:

```dart
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
      // 10*80 + 6.25*180 - 5*30 - 78 = 1697
      expect(r.bmr, 1697);
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

    test('sınır dışı girdiler kırpılır, patlamaz', () {
      final r = calculateCalorieTarget(
        const CalorieTargetInput(
          sex: BiologicalSex.male,
          age: 5,
          heightCm: 400,
          weightKg: 500,
          activity: ActivityLevel.active,
        ),
      );
      expect(r.bmr, greaterThan(0));
      expect(r.target, greaterThanOrEqualTo(1200));
    });

    test('aktivite faktörleri beklenen sırada', () {
      expect(ActivityLevel.sedentary.factor, 1.2);
      expect(ActivityLevel.light.factor, 1.375);
      expect(ActivityLevel.moderate.factor, 1.55);
      expect(ActivityLevel.active.factor, 1.725);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/calorie_target_calculator_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:nutrilens/core/services/calorie_target_calculator.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/core/services/calorie_target_calculator.dart`:

```dart
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

  final target = input.targetWeightKg;
  double adjusted = tdeeRaw;
  if (target != null) {
    final clampedTarget = target.clamp(_minWeightKg, _maxWeightKg);
    if (clampedTarget < weightKg - 1) {
      adjusted = tdeeRaw * 0.85;
    } else if (clampedTarget > weightKg + 1) {
      adjusted = tdeeRaw * 1.10;
    }
  }

  // Taban: BMR'nin altında kalıcı bir açık sağlıklı değil; 1200 de mutlak
  // alt sınır. İkisinin büyüğü kazanır.
  final floor = bmrRaw > _absoluteFloorKcal ? bmrRaw : _absoluteFloorKcal.toDouble();
  final floored = adjusted < floor ? floor : adjusted;

  return CalorieTargetResult(
    bmr: _round10(bmrRaw),
    tdee: _round10(tdeeRaw),
    target: _round10(floored),
  );
}

/// Kullanıcıya "2 137 kcal" göstermek sahte bir hassasiyet iddiası —
/// tahminin hata payı zaten ±%10. 10'a yuvarlıyoruz.
int _round10(double value) => (value / 10).round() * 10;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/calorie_target_calculator_test.dart`
Expected: PASS (10 test)

Not: `bmr` beklentileri `_round10` sonrası değerlerdir (1780, 1320, 1697). Test başarısız olursa önce beklenen aritmetiği elle doğrula, testi değiştirmeden önce implementasyonu kontrol et.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/calorie_target_calculator.dart test/core/services/calorie_target_calculator_test.dart
git commit -m "feat(calorie): kisisel gunluk kalori hedefi hesaplayicisi"
```

---

### Task 2: Drift şema v4 — `user_metrics` tablosu + `portionGrams` kolonu

**Files:**
- Create: `lib/config/drift/tables/user_metrics_table.dart`
- Modify: `lib/config/drift/tables/meal_entries_table.dart`
- Modify: `lib/config/drift/app_database.dart:17-52`
- Test: `test/config/drift/migration_v4_test.dart`

**Interfaces:**
- Consumes: `BiologicalSex`, `ActivityLevel` (Task 1) — DB'de string olarak saklanır
- Produces: `UserMetrics` Drift tablosu, `MealEntries.portionGrams` (int, nullable), `schemaVersion == 4`

- [ ] **Step 1: Write the failing test**

`test/config/drift/migration_v4_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('sema surumu 4', () {
    expect(db.schemaVersion, 4);
  });

  test('user_metrics tablosu bos baslar ve tek satir tutar', () async {
    expect(await db.select(db.userMetrics).get(), isEmpty);

    await db
        .into(db.userMetrics)
        .insertOnConflictUpdate(
          UserMetricsCompanion.insert(
            userId: 'guest',
            sex: 'female',
            birthYear: 1990,
            heightCm: 165,
            weightKg: 60,
            activityLevel: 'moderate',
            updatedAt: DateTime(2026, 8, 14),
          ),
        );

    final rows = await db.select(db.userMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.targetWeightKg, isNull);
  });

  test('meal_entries.portionGrams nullable ve varsayilan null', () async {
    await db
        .into(db.mealEntries)
        .insert(
          MealEntriesCompanion.insert(
            id: 'm1',
            userId: 'guest',
            mealName: 'Test',
            mealType: 'lunch',
            capturedAt: DateTime(2026, 8, 14),
          ),
        );

    final row = await db.select(db.mealEntries).getSingle();
    expect(row.portionGrams, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config/drift/migration_v4_test.dart`
Expected: FAIL — `db.userMetrics` tanımlı değil / `schemaVersion` 3 döndü

- [ ] **Step 3: Write minimal implementation**

`lib/config/drift/tables/user_metrics_table.dart` (yeni):

```dart
import 'package:drift/drift.dart';

/// Kullanıcının vücut ölçüleri — günlük kalori hedefi bundan hesaplanır.
///
/// Kullanıcı başına tek satır. Misafirde `userId == kGuestUserId`; kayıt
/// olunduğunda GuestMigrationService satırı yeni kimliğe taşır.
///
/// Yaş yerine doğum yılı saklanır: hedef her yıl kendiliğinden güncellensin,
/// kullanıcı profiline dönüp yaşını elle artırmak zorunda kalmasın.
class UserMetrics extends Table {
  TextColumn get userId => text()();

  /// `male` | `female` | `unspecified` — BiologicalSex.name karşılığı.
  TextColumn get sex => text()();
  IntColumn get birthYear => integer()();
  IntColumn get heightCm => integer()();
  RealColumn get weightKg => real()();

  /// null → kilo koruma. "Şu anki kilomu korumak istiyorum" seçeneği.
  RealColumn get targetWeightKg => real().nullable()();

  /// `sedentary` | `light` | `moderate` | `active` — ActivityLevel.name.
  TextColumn get activityLevel => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}
```

`lib/config/drift/tables/meal_entries_table.dart` — `confidence` satırının hemen altına ekle:

```dart
  /// Öğünün toplam gramajı (yiyecek + içecek). AI tahmin eder, kullanıcı
  /// porsiyon çarpanıyla ölçekler. Besin değerleri bu gramaj için TOPLAM
  /// değerdir — 100 g için değil. v4 öncesi kayıtlarda null.
  IntColumn get portionGrams => integer().nullable()();
```

`lib/config/drift/app_database.dart`:

```dart
import 'tables/user_metrics_table.dart';   // mevcut import'ların yanına

@DriftDatabase(
  tables: [
    FoodProducts,
    Additives,
    Allergens,
    ScanHistory,
    Favorites,
    Blacklist,
    CounterfeitProducts,
    MealEntries,
    UserMetrics,
  ],
)
```

`schemaVersion` ve `onUpgrade`:

```dart
  @override
  int get schemaVersion => 4;

  // ... onUpgrade içinde, from < 3 bloğunun altına:
        if (from < 4) {
          await m.createTable(userMetrics);
          await m.addColumn(mealEntries, mealEntries.portionGrams);
        }
```

- [ ] **Step 4: Codegen + test**

Run: `dart run build_runner build --delete-conflicting-outputs`
Sonra: `flutter test test/config/drift/migration_v4_test.dart`
Expected: PASS (3 test)

- [ ] **Step 5: Tüm testleri koştur**

Run: `flutter test`
Expected: mevcut 493 test + 13 yeni test geçer. Kırmızı varsa `MealEntriesCompanion.insert` çağrılarında pozisyonel/adlandırılmış argüman uyuşmazlığı ara — yeni nullable kolon zorunlu argüman eklemez, eklendiyse kolon `.nullable()` almamış demektir.

- [ ] **Step 6: Commit**

```bash
git add lib/config/drift test/config/drift/migration_v4_test.dart
git commit -m "feat(db): sema v4 - user_metrics tablosu ve ogun porsiyon gramaji"
```

---

### Task 3: `UserMetrics` veri katmanı + misafir devri

**Files:**
- Create: `lib/features/profile/domain/entities/user_metrics_entity.dart`
- Create: `lib/features/profile/data/datasources/user_metrics_local_datasource.dart`
- Create: `lib/features/profile/presentation/providers/user_metrics_provider.dart`
- Modify: `lib/core/session/guest_migration_service.dart`
- Test: `test/features/profile/user_metrics_local_datasource_test.dart`

**Interfaces:**
- Consumes: Task 1 (`BiologicalSex`, `ActivityLevel`, `calculateCalorieTarget`), Task 2 (`db.userMetrics`)
- Produces:
  - `class UserMetricsEntity { String userId; BiologicalSex sex; int birthYear; int heightCm; double weightKg; double? targetWeightKg; ActivityLevel activity; DateTime updatedAt; int ageAt(DateTime now); CalorieTargetInput toCalculatorInput(DateTime now); UserMetricsEntity copyWith({..., bool clearTargetWeight}); }`
  - `final userMetricsLocalDataSourceProvider = Provider<UserMetricsLocalDataSource>`
  - `abstract interface class UserMetricsLocalDataSource { Future<UserMetricsEntity?> get(String userId); Future<void> save(UserMetricsEntity m); Future<void> reassignOwner({required String fromUserId, required String toUserId}); }`
  - `final userMetricsProvider = FutureProvider<UserMetricsEntity?>` — `effectiveUserIdProvider`'a bağlı
  - `final dailyCalorieTargetProvider = Provider<int>` — metrics yoksa `kDefaultDailyCalories`

- [ ] **Step 1: Write the failing test**

`test/features/profile/user_metrics_local_datasource_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/features/profile/data/datasources/user_metrics_local_datasource.dart';
import 'package:nutrilens/features/profile/domain/entities/user_metrics_entity.dart';

void main() {
  late AppDatabase db;
  late UserMetricsLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = UserMetricsLocalDataSourceImpl(db);
  });
  tearDown(() => db.close());

  UserMetricsEntity sample(String userId) => UserMetricsEntity(
    userId: userId,
    sex: BiologicalSex.female,
    birthYear: 1990,
    heightCm: 165,
    weightKg: 60,
    targetWeightKg: 55,
    activity: ActivityLevel.moderate,
    updatedAt: DateTime(2026, 8, 14),
  );

  test('kayit yoksa null doner', () async {
    expect(await ds.get('guest'), isNull);
  });

  test('kaydeder ve geri okur', () async {
    await ds.save(sample('guest'));
    final read = await ds.get('guest');
    expect(read, isNotNull);
    expect(read!.sex, BiologicalSex.female);
    expect(read.activity, ActivityLevel.moderate);
    expect(read.targetWeightKg, 55);
  });

  test('ayni kullanici icin ikinci kayit uzerine yazar, satir cogaltmaz', () async {
    await ds.save(sample('guest'));
    await ds.save(sample('guest').copyWith(weightKg: 62));
    final rows = await db.select(db.userMetrics).get();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 62);
  });

  test('misafir satiri yeni kullaniciya tasinir', () async {
    await ds.save(sample('guest'));
    await ds.reassignOwner(fromUserId: 'guest', toUserId: 'user-1');
    expect(await ds.get('guest'), isNull);
    expect(await ds.get('user-1'), isNotNull);
  });

  test('hedef kullanicida zaten kayit varsa misafir satiri onu ezmez', () async {
    await ds.save(sample('guest').copyWith(weightKg: 60));
    await ds.save(sample('user-1').copyWith(weightKg: 90));
    await ds.reassignOwner(fromUserId: 'guest', toUserId: 'user-1');
    final kept = await ds.get('user-1');
    expect(kept!.weightKg, 90, reason: 'gercek hesabin verisi korunmali');
    expect(await ds.get('guest'), isNull, reason: 'misafir satiri temizlenmeli');
  });

  test('yas dogum yilindan turetilir', () {
    final m = sample('guest');
    expect(m.ageAt(DateTime(2026, 8, 14)), 36);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/profile/user_metrics_local_datasource_test.dart`
Expected: FAIL — dosyalar yok

- [ ] **Step 3: Write the entity**

`lib/features/profile/domain/entities/user_metrics_entity.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../../../core/services/calorie_target_calculator.dart';

/// Kullanıcının vücut ölçüleri. Kalori hedefi bundan türetilir.
class UserMetricsEntity extends Equatable {
  final String userId;
  final BiologicalSex sex;
  final int birthYear;
  final int heightCm;
  final double weightKg;
  final double? targetWeightKg;
  final ActivityLevel activity;
  final DateTime updatedAt;

  const UserMetricsEntity({
    required this.userId,
    required this.sex,
    required this.birthYear,
    required this.heightCm,
    required this.weightKg,
    this.targetWeightKg,
    required this.activity,
    required this.updatedAt,
  });

  /// Doğum yılından türetilen yaş. Gün/ay bilgisi sorulmadığı için yıl farkı
  /// yeterli — kalori hesabında bir yıllık sapmanın etkisi 5 kcal.
  int ageAt(DateTime now) => now.year - birthYear;

  CalorieTargetInput toCalculatorInput(DateTime now) => CalorieTargetInput(
    sex: sex,
    age: ageAt(now),
    heightCm: heightCm,
    weightKg: weightKg,
    targetWeightKg: targetWeightKg,
    activity: activity,
  );

  UserMetricsEntity copyWith({
    String? userId,
    BiologicalSex? sex,
    int? birthYear,
    int? heightCm,
    double? weightKg,
    double? targetWeightKg,
    bool clearTargetWeight = false,
    ActivityLevel? activity,
    DateTime? updatedAt,
  }) {
    return UserMetricsEntity(
      userId: userId ?? this.userId,
      sex: sex ?? this.sex,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: clearTargetWeight
          ? null
          : (targetWeightKg ?? this.targetWeightKg),
      activity: activity ?? this.activity,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    sex,
    birthYear,
    heightCm,
    weightKg,
    targetWeightKg,
    activity,
    updatedAt,
  ];
}
```

- [ ] **Step 4: Write the datasource**

`lib/features/profile/data/datasources/user_metrics_local_datasource.dart`:

```dart
import 'package:drift/drift.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/services/calorie_target_calculator.dart';
import '../../domain/entities/user_metrics_entity.dart';

abstract interface class UserMetricsLocalDataSource {
  Future<UserMetricsEntity?> get(String userId);
  Future<void> save(UserMetricsEntity metrics);

  /// Misafir satırını gerçek hesaba taşır. Hedef kullanıcıda zaten kayıt
  /// varsa onu KORUR ve yalnızca misafir satırını siler — hesabında ölçü
  /// girmiş biri, misafirken girdiği eski değerlerle ezilmemeli.
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  });
}

final class UserMetricsLocalDataSourceImpl implements UserMetricsLocalDataSource {
  final AppDatabase _db;

  const UserMetricsLocalDataSourceImpl(this._db);

  @override
  Future<UserMetricsEntity?> get(String userId) async {
    final row = await (_db.select(
      _db.userMetrics,
    )..where((t) => t.userId.equals(userId))).getSingleOrNull();
    if (row == null) return null;
    return UserMetricsEntity(
      userId: row.userId,
      sex: BiologicalSex.values.firstWhere(
        (e) => e.name == row.sex,
        orElse: () => BiologicalSex.unspecified,
      ),
      birthYear: row.birthYear,
      heightCm: row.heightCm,
      weightKg: row.weightKg,
      targetWeightKg: row.targetWeightKg,
      activity: ActivityLevel.values.firstWhere(
        (e) => e.name == row.activityLevel,
        orElse: () => ActivityLevel.sedentary,
      ),
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> save(UserMetricsEntity m) async {
    await _db
        .into(_db.userMetrics)
        .insertOnConflictUpdate(
          UserMetricsCompanion.insert(
            userId: m.userId,
            sex: m.sex.name,
            birthYear: m.birthYear,
            heightCm: m.heightCm,
            weightKg: m.weightKg,
            targetWeightKg: Value(m.targetWeightKg),
            activityLevel: m.activity.name,
            updatedAt: m.updatedAt,
          ),
        );
  }

  @override
  Future<void> reassignOwner({
    required String fromUserId,
    required String toUserId,
  }) async {
    final existing = await get(toUserId);
    final guestRow = await get(fromUserId);
    if (guestRow != null && existing == null) {
      await save(guestRow.copyWith(userId: toUserId));
    }
    await (_db.delete(
      _db.userMetrics,
    )..where((t) => t.userId.equals(fromUserId))).go();
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/profile/user_metrics_local_datasource_test.dart`
Expected: PASS (6 test)

- [ ] **Step 6: Providers**

`lib/features/profile/presentation/providers/user_metrics_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/drift/app_database.dart';
import '../../../../core/services/calorie_target_calculator.dart';
import '../../../../core/session/app_session.dart';
import '../../data/datasources/user_metrics_local_datasource.dart';
import '../../domain/entities/user_metrics_entity.dart';

final userMetricsLocalDataSourceProvider = Provider<UserMetricsLocalDataSource>(
  (ref) => UserMetricsLocalDataSourceImpl(ref.watch(appDatabaseProvider)),
);

final userMetricsProvider = FutureProvider<UserMetricsEntity?>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  return ref.watch(userMetricsLocalDataSourceProvider).get(userId);
});

/// Günlük kalori hedefi. Metrics girilmemişse besin etiketlerinin klasik
/// 2000 kcal varsayımına düşer — hiçbir ekran metrics'in varlığına bağımlı
/// olmamalı.
final dailyCalorieTargetProvider = Provider<int>((ref) {
  final metrics = ref.watch(userMetricsProvider).valueOrNull;
  if (metrics == null) return kDefaultDailyCalories;
  return calculateCalorieTarget(
    metrics.toCalculatorInput(DateTime.now()),
  ).target;
});
```

`appDatabaseProvider` ve `effectiveUserIdProvider`'ın gerçek import yollarını doğrula:
Run: `grep -rn "final appDatabaseProvider\|final effectiveUserIdProvider" lib`
Import satırlarını çıkan yollara göre düzelt.

- [ ] **Step 7: Misafir devrine bağla**

`lib/core/session/guest_migration_service.dart` — sınıfa `UserMetricsLocalDataSource _metricsDs` alanını constructor parametresi olarak ekle, `migrate(newUserId:)` içinde Drift re-key adımlarının yanına:

```dart
    await _metricsDs.reassignOwner(
      fromUserId: kGuestUserId,
      toUserId: newUserId,
    );
```

`guestMigrationServiceProvider`'a yeni bağımlılığı geçir (provider tanımını `grep -rn "guestMigrationServiceProvider" lib` ile bul).

- [ ] **Step 8: Run full suite**

Run: `flutter analyze --fatal-infos && flutter test`
Expected: temiz + tüm testler geçer

- [ ] **Step 9: Commit**

```bash
git add lib/features/profile lib/core/session/guest_migration_service.dart test/features/profile
git commit -m "feat(profile): kullanici olcum verisi katmani ve misafir devri"
```

---

### Task 4: Porsiyon gramajını uçtan uca sakla

Bugün `MealAnalysisResult.portionGrams` ekranda gösteriliyor ama kaydedilmiyor; öğün detayına gidince gramaj kayıp.

**Files:**
- Modify: `lib/features/meals/domain/entities/meal_entry_entity.dart`
- Modify: `lib/features/meals/data/datasources/meal_local_datasource.dart:61-92` (saveMeal) ve satır okuma eşlemesi
- Modify: `lib/features/scanner/presentation/screens/food_result_screen.dart:454` civarı (`_saveMeal`)
- Test: `test/features/meals/meal_portion_persistence_test.dart`

**Interfaces:**
- Consumes: Task 2 (`MealEntries.portionGrams`)
- Produces: `MealEntryEntity.portionGrams` (`int?`) — Task 5 bunu okur

- [ ] **Step 1: Write the failing test**

`test/features/meals/meal_portion_persistence_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/features/meals/data/datasources/meal_local_datasource.dart';
import 'package:nutrilens/features/meals/domain/entities/meal_entry_entity.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';

void main() {
  late AppDatabase db;
  late MealLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = MealLocalDataSourceImpl(db);
  });
  tearDown(() => db.close());

  MealEntryEntity meal({int? portionGrams}) => MealEntryEntity(
    id: 'm1',
    userId: 'guest',
    mealName: 'Mercimek çorbası',
    mealType: MealType.lunch,
    capturedAt: DateTime(2026, 8, 14),
    nutriments: const NutrimentsEntity(energyKcal: 320),
    calories: 320,
    portionGrams: portionGrams,
    syncStatus: 'local_only',
  );

  test('porsiyon gramaji kaydedilir ve geri okunur', () async {
    await ds.saveMeal(meal(portionGrams: 350));
    final read = await ds.getMealById('m1');
    expect(read!.portionGrams, 350);
  });

  test('gramaj verilmezse null kalir, kayit yine calisir', () async {
    await ds.saveMeal(meal());
    final read = await ds.getMealById('m1');
    expect(read!.portionGrams, isNull);
    expect(read.calories, 320);
  });
}
```

`MealType.lunch` ve `MealLocalDataSourceImpl` constructor imzasını doğrula:
Run: `grep -rn "enum MealType" -A6 lib && grep -n "MealLocalDataSourceImpl(" lib/features/meals/data/datasources/meal_local_datasource.dart`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/meals/meal_portion_persistence_test.dart`
Expected: FAIL — `portionGrams` adlı parametre yok

- [ ] **Step 3: Entity'ye alanı ekle**

`meal_entry_entity.dart` — `confidence` alanının yanına `final int? portionGrams;`, constructor'a `this.portionGrams,`, `props` listesine `portionGrams`, `copyWith` varsa oraya da ekle.

- [ ] **Step 4: Datasource eşlemesini güncelle**

`meal_local_datasource.dart`:
- `saveMeal` içindeki `MealEntriesCompanion.insert(...)` çağrısına `portionGrams: Value(meal.portionGrams),` ekle.
- Drift satırını entity'ye çeviren eşleme fonksiyonuna (`_toEntity` benzeri, dosyada `MealEntryEntity(` geçen yer) `portionGrams: row.portionGrams,` ekle. Eşleme birden fazla yerde tekrar ediyorsa hepsini güncelle:
  Run: `grep -n "MealEntryEntity(" lib/features/meals/data/datasources/meal_local_datasource.dart`

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/meals/meal_portion_persistence_test.dart`
Expected: PASS (2 test)

- [ ] **Step 6: Kayıt çağrısını besle**

`food_result_screen.dart` — `_saveMeal` içinde `MealEntryEntity(...)` kurulurken ölçeklenmiş gramajı geçir. Dosyada `(result.portionGrams * _portionMultiplier).round()` ifadesi zaten iki yerde var (satır ~454 ve ~615); kayıt yolundakine karşılık gelen değeri entity'ye ekle:

```dart
  portionGrams: (result.portionGrams * _portionMultiplier).round(),
```

- [ ] **Step 7: Run full suite + commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/features/meals lib/features/scanner test/features/meals/meal_portion_persistence_test.dart
git commit -m "feat(meals): ogun porsiyon gramajini kalici sakla"
```

---

### Task 5: Besin tablosunun referans tabanını parametreleştir

`EditorialNutrientTable` sütun başlığına `'100g'` sabitini basıyor (satır ~167) ve öğün ekranlarında bu yanlış — oradaki sayılar porsiyon toplamı. `BentoNutritionGrid` de `_dailyCalories = 2000` sabitine bağlı.

**Files:**
- Modify: `lib/features/product/presentation/widgets/editorial_nutrient_table.dart:167,205`
- Modify: `lib/features/product/presentation/widgets/bento_nutrition_grid.dart:12-22,64,316`
- Modify: `lib/features/product/presentation/screens/product_detail_screen.dart:546`
- Modify: `lib/features/meals/presentation/screens/meal_detail_screen.dart:106,108`
- Modify: `lib/features/scanner/presentation/screens/food_result_screen.dart:754,756`
- Modify: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/product/nutrition_basis_label_test.dart`

**Interfaces:**
- Consumes: Task 3 (`dailyCalorieTargetProvider`), Task 4 (`MealEntryEntity.portionGrams`)
- Produces: `EditorialNutrientTable({required NutrimentsEntity nutriments, String? basisLabel})`, `BentoNutritionGrid({required NutrimentsEntity nutriments, String? basisLabel, int dailyCalories = kDefaultDailyCalories})`

- [ ] **Step 1: l10n anahtarlarını ekle**

`lib/l10n/app_tr.arb`:

```json
  "nutritionBasisPortion": "porsiyon",
  "nutritionBasisGrams": "{grams} g",
  "dailyValueNotePersonal": "* Yüzdelik değerler günlük {kcal} kcal'lik kişisel hedefinize göre hesaplanmıştır.",
```

`lib/l10n/app_en.arb`:

```json
  "nutritionBasisPortion": "portion",
  "nutritionBasisGrams": "{grams} g",
  "dailyValueNotePersonal": "* Percentages are based on your personal daily target of {kcal} kcal.",
```

Placeholder'lı anahtarlar için arb'de metadata gerekiyorsa mevcut placeholder'lı bir anahtarı örnek al:
Run: `grep -n "placeholders" -B4 -A8 lib/l10n/app_tr.arb | head -30`

Sonra: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

`test/features/product/nutrition_basis_label_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/presentation/widgets/editorial_nutrient_table.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  const nutriments = NutrimentsEntity(energyKcal: 320, fat: 12, proteins: 9);

  testWidgets('basisLabel verilmezse 100g gosterir (paketli urun)', (t) async {
    await t.pumpWidget(host(const EditorialNutrientTable(nutriments: nutriments)));
    expect(find.text('100g'), findsOneWidget);
  });

  testWidgets('basisLabel verilirse onu gosterir (ogun)', (t) async {
    await t.pumpWidget(
      host(
        const EditorialNutrientTable(nutriments: nutriments, basisLabel: '350 g'),
      ),
    );
    expect(find.text('350 g'), findsOneWidget);
    expect(find.text('100g'), findsNothing);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/product/nutrition_basis_label_test.dart`
Expected: İlk test PASS, ikinci test FAIL — `basisLabel` adlı parametre yok

- [ ] **Step 4: Widget'ları parametreleştir**

`editorial_nutrient_table.dart`:

```dart
  /// Tablodaki sayıların hangi miktara ait olduğu. Paketli ürünlerde
  /// `'100g'` (etiket standardı), öğünlerde porsiyonun gerçek gramajı —
  /// öğün değerleri 100 g için değil, porsiyon TOPLAMI için gelir.
  final String? basisLabel;
```

Constructor'a `this.basisLabel` ekle; satır ~167'deki sabiti değiştir:

```dart
  Text(basisLabel ?? '100g', ...)   // mevcut stil argümanlarını koru
```

Satır ~205'teki `context.l10n.dailyValueNote` çağrısını Task 6'da değiştireceğiz — şimdilik dokunma.

`bento_nutrition_grid.dart`: `static const _dailyCalories = 2000.0;` satırını sil, yerine constructor alanı:

```dart
  /// Yüzdeliklerin hesaplandığı günlük kalori referansı. Kullanıcının
  /// kişisel hedefi yoksa besin etiketi standardı olan 2000 kcal.
  final int dailyCalories;
  final String? basisLabel;
```

`const BentoNutritionGrid({super.key, required this.nutriments, this.dailyCalories = kDefaultDailyCalories, this.basisLabel});`

Satır ~64'teki `_dailyCalories` kullanımını `dailyCalories` ile değiştir (double'a çevir: `dailyCalories.toDouble()`).

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/product/nutrition_basis_label_test.dart`
Expected: PASS (2 test)

- [ ] **Step 6: Çağrı yerlerini besle**

- `product_detail_screen.dart:546` → değişiklik yok (varsayılan `100g` doğru).
- `meal_detail_screen.dart:106,108` → `BentoNutritionGrid` ve `EditorialNutrientTable`'a:
  ```dart
  basisLabel: meal.portionGrams != null
      ? context.l10n.nutritionBasisGrams(meal.portionGrams!)
      : context.l10n.nutritionBasisPortion,
  ```
- `food_result_screen.dart:754,756` → `scaledPortion` değişkeni zaten hesaplanmış (satır ~615):
  ```dart
  basisLabel: context.l10n.nutritionBasisGrams(scaledPortion),
  ```

- [ ] **Step 7: Run full suite + commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/features lib/l10n test/features/product/nutrition_basis_label_test.dart
git commit -m "fix(nutrition): ogun tablosu 100g yerine gercek porsiyon gramajini gosterir"
```

---

### Task 6: Kişisel hedefi yüzdeliklere bağla

**Files:**
- Modify: `lib/features/product/presentation/widgets/editorial_nutrient_table.dart:205`
- Modify: `lib/features/product/presentation/screens/product_detail_screen.dart:546`
- Modify: `lib/features/meals/presentation/screens/meal_detail_screen.dart:106`
- Modify: `lib/features/scanner/presentation/screens/food_result_screen.dart:754`
- Test: `test/features/product/daily_target_wiring_test.dart`

**Interfaces:**
- Consumes: Task 3 (`dailyCalorieTargetProvider`, `userMetricsProvider`), Task 5 (`BentoNutritionGrid.dailyCalories`)
- Produces: `EditorialNutrientTable.personalDailyCalories` (`int?`) — null ise mevcut 2000 kcal dipnotu korunur

- [ ] **Step 1: Write the failing test**

`test/features/product/daily_target_wiring_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/calorie_target_calculator.dart';
import 'package:nutrilens/features/product/domain/entities/nutriments_entity.dart';
import 'package:nutrilens/features/product/presentation/widgets/bento_nutrition_grid.dart';
import 'package:nutrilens/l10n/generated/app_localizations.dart';

void main() {
  Widget host(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );

  testWidgets('varsayilan referans 2000 kcal', (t) async {
    await t.pumpWidget(
      host(
        const BentoNutritionGrid(
          nutriments: NutrimentsEntity(energyKcal: 1000),
        ),
      ),
    );
    // 1000 / 2000 = %50
    expect(find.textContaining('50'), findsWidgets);
  });

  testWidgets('kisisel hedef verilince yuzde ona gore degisir', (t) async {
    await t.pumpWidget(
      host(
        const BentoNutritionGrid(
          nutriments: NutrimentsEntity(energyKcal: 1000),
          dailyCalories: 2500,
        ),
      ),
    );
    // 1000 / 2500 = %40
    expect(find.textContaining('40'), findsWidgets);
  });

  test('metrics yoksa saglayici 2000 kcal doner', () {
    final container = ProviderContainer(
      overrides: [
        userMetricsProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(dailyCalorieTargetProvider), kDefaultDailyCalories);
  });

  test('metrics varsa saglayici hesaplanan hedefi doner', () async {
    final metrics = UserMetricsEntity(
      userId: 'guest',
      sex: BiologicalSex.male,
      birthYear: 1996,
      heightCm: 180,
      weightKg: 80,
      activity: ActivityLevel.sedentary,
      updatedAt: DateTime(2026, 8, 14),
    );
    final container = ProviderContainer(
      overrides: [
        userMetricsProvider.overrideWith((ref) async => metrics),
      ],
    );
    addTearDown(container.dispose);
    // Saglayici FutureProvider'a bagli: once cozulmesini bekle.
    await container.read(userMetricsProvider.future);
    final expected = calculateCalorieTarget(
      metrics.toCalculatorInput(DateTime(2026, 8, 14)),
    ).target;
    expect(container.read(dailyCalorieTargetProvider), expected);
  });
}
```

Yüzdenin ekranda tam olarak nasıl yazıldığını (`%50`, `50%`, `50`) doğrula ve beklentiyi ona göre düzelt:
Run: `grep -n "percent" -A6 lib/features/product/presentation/widgets/bento_nutrition_grid.dart | head -40`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/product/daily_target_wiring_test.dart`
Expected: İkinci test FAIL (Task 5 yapıldıysa geçebilir — o durumda bu task yalnızca bağlama)

- [ ] **Step 3: Çağrı yerlerinde hedefi geçir**

Üç çağrı yerinde de (`product_detail_screen`, `meal_detail_screen`, `food_result_screen`) widget bir `ConsumerWidget`/`Consumer` içindeyse:

```dart
  dailyCalories: ref.watch(dailyCalorieTargetProvider),
```

Ekran `StatelessWidget` ise `Consumer(builder: (context, ref, _) => BentoNutritionGrid(...))` ile sar. Hangi ekranın hangi tip olduğunu doğrula:
Run: `grep -n "class .*Screen extends" lib/features/product/presentation/screens/product_detail_screen.dart lib/features/meals/presentation/screens/meal_detail_screen.dart lib/features/scanner/presentation/screens/food_result_screen.dart`

- [ ] **Step 4: Dipnotu kişiselleştir**

`editorial_nutrient_table.dart:205` — widget'a `final int? personalDailyCalories;` alanı ekle ve:

```dart
  Text(
    personalDailyCalories != null
        ? context.l10n.dailyValueNotePersonal(personalDailyCalories!)
        : context.l10n.dailyValueNote,
    ...
  )
```

Çağrı yerlerinde `personalDailyCalories:` değerini yalnızca metrics varsa geçir:

```dart
  personalDailyCalories: ref.watch(userMetricsProvider).valueOrNull == null
      ? null
      : ref.watch(dailyCalorieTargetProvider),
```

- [ ] **Step 5: Run full suite + commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/features test/features/product/daily_target_wiring_test.dart
git commit -m "feat(nutrition): yuzdelik degerleri kisisel kalori hedefine bagla"
```

---

### Task 7: Ölçü toplama akışı (5 adım) + analytics

**Files:**
- Create: `lib/features/profile/presentation/screens/metrics_wizard_screen.dart`
- Create: `lib/features/profile/presentation/widgets/metrics_step_scaffold.dart`
- Create: `lib/core/services/metrics_prompt_store.dart`
- Modify: `lib/core/analytics/analytics_event.dart`
- Modify: `lib/l10n/app_tr.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/profile/metrics_wizard_test.dart`, `test/core/services/metrics_prompt_store_test.dart`

**Interfaces:**
- Consumes: Task 1, Task 3
- Produces:
  - `MetricsWizardScreen` — tamamlanınca `UserMetricsEntity` kaydeder; mevcut kayıt varsa alanları dolu açılır
  - `class MetricsPromptStore { Future<bool> shouldPrompt(); Future<void> markDismissed(); Future<void> markCompleted(); }`
  - `final metricsPromptStoreProvider = Provider<MetricsPromptStore>` — Task 8 tetikleyicide bunu okur
  - `AnalyticsEvents.metricsPromptShown / metricsStepCompleted / metricsCompleted / metricsDismissed`

- [ ] **Step 1: Analytics olaylarını ekle**

`lib/core/analytics/analytics_event.dart` — `paywallShown` satırının altına:

```dart
  // --- Kişisel kalori hedefi ------------------------------------------
  /// İlk öğün kaydından sonra ölçü sihirbazı açıldı.
  static const metricsPromptShown = 'metrics_prompt_shown';

  /// props: `step` (sex|body|target|activity)
  static const metricsStepCompleted = 'metrics_step_completed';

  /// props: `target_kcal`, `activity`
  static const metricsCompleted = 'metrics_completed';

  /// props: `step` — hangi adımda bırakıldı. Formun nerede kaybettiğini
  /// ölçmeden adım sayısını tartışmak kör uçuş.
  static const metricsDismissed = 'metrics_dismissed';
```

- [ ] **Step 2: Prompt store testi yaz**

`test/core/services/metrics_prompt_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/core/services/metrics_prompt_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ilk cagride sorulmali', () async {
    final store = MetricsPromptStore(await SharedPreferences.getInstance());
    expect(await store.shouldPrompt(), isTrue);
  });

  test('reddedildikten sonra bir daha sorulmaz', () async {
    final store = MetricsPromptStore(await SharedPreferences.getInstance());
    await store.markDismissed();
    expect(await store.shouldPrompt(), isFalse);
  });

  test('tamamlandiktan sonra bir daha sorulmaz', () async {
    final store = MetricsPromptStore(await SharedPreferences.getInstance());
    await store.markCompleted();
    expect(await store.shouldPrompt(), isFalse);
  });
}
```

`shared_preferences` kullanımı projede yerleşik mi doğrula; değilse mevcut kalıcı depolama kalıbını kullan:
Run: `grep -rn "SharedPreferences" lib/core/services/*.dart | head -5`
(`camera_priming_store.dart` ve `guest_scan_counter.dart` aynı işi yapan mevcut örnekler — birebir o kalıbı izle.)

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/services/metrics_prompt_store_test.dart`
Expected: FAIL — dosya yok

- [ ] **Step 4: Store'u yaz**

`lib/core/services/metrics_prompt_store.dart` — `camera_priming_store.dart` dosyasını referans alarak birebir aynı yapıda yaz. Tek anahtar: `metrics_prompt_settled` (bool). `shouldPrompt()` bu anahtar yoksa `true` döner; `markDismissed()` ve `markCompleted()` `true` yazar.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/services/metrics_prompt_store_test.dart`
Expected: PASS (3 test)

- [ ] **Step 6: Sihirbaz ekranını yaz**

`metrics_wizard_screen.dart` — `PageView` tabanlı 5 adım, geri tuşu adım adım geri gider:

1. **Cinsiyet** — 3 kart: `metricsSexFemale`, `metricsSexMale`, `metricsSexUnspecified`
2. **Vücut** — 3 sayısal alan: yaş (16–100), boy cm (120–230), kilo kg (30–300). Alan bazlı hata metni: `metricsRangeError`
3. **Hedef kilo** — sayısal alan (30–300) + "Şu anki kilomu korumak istiyorum" seçeneği → `targetWeightKg = null`
4. **Aktivite** — 4 kart: `metricsActivitySedentary/Light/Moderate/Active`
5. **Sonuç** — `calculateCalorieTarget` sonucu büyük punto + `metricsMedicalDisclaimer` + kayıt CTA'sı (`metricsSaveToAccountCta`)

Görsel dil: Profil ekranındaki kart düzenini izle (yumuşak gradyan zemin, beyaz daire ikon rozeti, 20–24 köşe yarıçapı). Yeni bir tasarım sistemi kurma — Spec B o işi ayrıca ele alacak.

Her adım tamamlandığında:
```dart
  ref.read(analyticsServiceProvider).track(
    AnalyticsEvents.metricsStepCompleted,
    props: {'step': 'sex'},
  );
```

Kapatma/geri ile çıkışta `metricsDismissed` + `markDismissed()`; 5. adımda kaydet + `metricsCompleted` + `markCompleted()`.

`analyticsServiceProvider`'ın adını doğrula:
Run: `grep -rn "analyticsServiceProvider\|final analytics" lib/core/analytics/*.dart | head`

- [ ] **Step 7: Widget testi yaz ve koştur**

`test/features/profile/metrics_wizard_test.dart` — en az üç senaryo:
- 5 adım baştan sona tamamlanınca `UserMetricsLocalDataSource.save` çağrılır ve kaydedilen değerler girilenlerle eşleşir (sahte datasource ile)
- Aralık dışı kilo (500) girildiğinde hata metni görünür ve ileri gidilemez
- 3. adımda "kilomu korumak istiyorum" seçilirse kaydedilen `targetWeightKg` null olur

Run: `flutter test test/features/profile/metrics_wizard_test.dart`
Expected: PASS

- [ ] **Step 8: Emülatörde yerleşim doğrulaması**

Widget testleri bu projede metin kaynaklı dikey yerleşimi yakalamıyor (test fontu gerçek Roboto'dan farklı kırılıyor). Küçük ekranda taşma olmadığını gerçek cihazda doğrula:

```bash
adb -s emulator-5554 shell wm size 720x1280 && adb -s emulator-5554 shell wm density 320
```

Beş adımın da ekran görüntüsünü al, taşma/kesilme yoksa boyutu geri al (`wm size reset`, `wm density reset`).
**ADB uyarısı:** hedefi daima `-s emulator-5554` ile belirt — ADB'de fiziksel telefon da bağlı olabiliyor.

- [ ] **Step 9: Commit**

```bash
git add lib/features/profile lib/core/services/metrics_prompt_store.dart lib/core/analytics lib/l10n test/features/profile test/core/services/metrics_prompt_store_test.dart
git commit -m "feat(profile): kisisel kalori icin 5 adimli olcum sihirbazi"
```

---

### Task 8: Tetikleyici + Öğünlerim'de alınan/hedef + profil giriş noktası

**Files:**
- Modify: `lib/features/scanner/presentation/screens/food_result_screen.dart` (`_saveMeal` sonrası)
- Modify: `lib/features/meals/presentation/screens/meals_screen.dart`
- Modify: `lib/features/meals/presentation/widgets/calorie_stacked_bar_chart.dart`
- Modify: `lib/features/profile/presentation/screens/profile_screen.dart`
- Test: `test/features/meals/daily_target_summary_test.dart`

**Interfaces:**
- Consumes: Task 3 (`dailyCalorieTargetProvider`, `userMetricsProvider`), Task 7 (`MetricsWizardScreen`, `MetricsPromptStore`)
- Produces: yok

- [ ] **Step 1: Tetikleyiciyi bağla**

`food_result_screen.dart` — `_saveMeal` başarıyla tamamlanıp `meal_added` gönderildikten sonra:

```dart
    if (!mounted) return;
    final promptStore = ref.read(metricsPromptStoreProvider);
    final metrics = await ref.read(userMetricsLocalDataSourceProvider)
        .get(ref.read(effectiveUserIdProvider));
    if (metrics == null && await promptStore.shouldPrompt()) {
      if (!mounted) return;
      ref.read(analyticsServiceProvider).track(AnalyticsEvents.metricsPromptShown);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MetricsWizardScreen()),
      );
    }
```

`await` sonrası her `context` kullanımından önce `mounted` kontrolü şart — bu projede daha önce dispose sonrası `ref` erişimi hatası yaşandı (commit `accf979`).

- [ ] **Step 2: Write the failing test**

`test/features/meals/daily_target_summary_test.dart` — `meals_screen`'in günlük özet satırını sahte sağlayıcılarla test et:
- metrics yokken "1 420 / 2 000 kcal" görünür
- `dailyCalorieTargetProvider` 2500 override edildiğinde "1 420 / 2 500 kcal" görünür
- toplam hedefi aşınca aşım göstergesi görünür

Run: `flutter test test/features/meals/daily_target_summary_test.dart`
Expected: FAIL — özet satırı yok

- [ ] **Step 3: Özet satırını ekle**

`meals_screen.dart` — liste başlığının üstüne günün toplamı / hedef satırı ve ilerleme çubuğu. Bugünün toplamı için mevcut `MealLocalDataSource.totalCalories({...})` kullanılır; yeni sorgu yazma.

l10n: `dailyCalorieSummary` → `"{consumed} / {target} kcal"`, `dailyCalorieOver` → `"Hedefin {over} kcal üzerindesin"`.

- [ ] **Step 4: Grafiğe hedef çizgisi**

`calorie_stacked_bar_chart.dart` — `int? targetKcal` parametresi ekle; null değilse yatay kesikli çizgi çiz. Null geçildiğinde grafik bugünküyle aynı görünmeli.

- [ ] **Step 5: Profil giriş noktası**

`profile_screen.dart` — "Health Filters" bölümünün üstüne yeni kart: metrics varsa "Günlük hedefin **2 180 kcal**" alt metniyle, yoksa "Kişisel kalori hedefini hesapla" çağrısıyla. Dokununca `MetricsWizardScreen` açılır (kayıt varsa değerler dolu gelir).

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/meals/daily_target_summary_test.dart`
Expected: PASS

- [ ] **Step 7: Emülatörde uçtan uca doğrula**

Öğün kaydet → sihirbaz açılıyor mu → tamamla → Öğünlerim'de hedef görünüyor mu → grafik çizgisi doğru yerde mi. `wm size 720x1280` ile taşma kontrolü.

- [ ] **Step 8: Run full suite + commit**

```bash
flutter analyze --fatal-infos && flutter test
git add lib/features test/features/meals/daily_target_summary_test.dart
git commit -m "feat(meals): gunluk alinan/hedef ozeti ve olcum sihirbazi tetikleyicisi"
```

---

### Task 9: Supabase senkronu + mağaza beyanı

**Files:**
- Create: `supabase/migrations/20260814120000_user_metrics_and_meal_portion.sql`
- Modify: `lib/features/meals/data/datasources/meal_remote_datasource.dart`
- Create: `lib/features/profile/data/datasources/user_metrics_remote_datasource.dart`
- Modify: `lib/features/profile/presentation/providers/user_metrics_provider.dart`

**Interfaces:**
- Consumes: Task 3, Task 4
- Produces: `UserMetricsRemoteDataSource { Future<void> upsert(UserMetricsEntity m); Future<UserMetricsEntity?> fetch(String userId); }`

- [ ] **Step 1: Migration'ı yaz**

`supabase/migrations/20260814120000_user_metrics_and_meal_portion.sql`:

```sql
-- Kişisel kalori hedefi için vücut ölçüleri. Yeni tablo değil:
-- user_profiles zaten var, RLS'li ve handle_new_user ile otomatik oluşuyor.
alter table public.user_profiles
  add column if not exists sex text,
  add column if not exists birth_year integer,
  add column if not exists height_cm integer,
  add column if not exists weight_kg double precision,
  add column if not exists target_weight_kg double precision,
  add column if not exists activity_level text;

-- Öğün porsiyon gramajı: besin değerleri 100 g için değil, bu gramaj için
-- TOPLAM. Bulut senkronu bu bilgiyi kaybetmemeli.
alter table public.meal_entries
  add column if not exists portion_grams integer;
```

- [ ] **Step 2: Migration'ı uygula**

```bash
supabase db push
```

Sürüm çakışması olursa (MCP/dashboard zaman damgalı sürüm yazmış olabilir) `supabase migration list` ile karşılaştır, `supabase migration repair` ile hizala. Uzak şemayı doğrula:

```sql
select column_name from information_schema.columns
where table_name = 'user_profiles' and column_name in
  ('sex','birth_year','height_cm','weight_kg','target_weight_kg','activity_level');
```

- [ ] **Step 3: Uzak veri kaynağını yaz**

`user_metrics_remote_datasource.dart` — `MealRemoteDataSource` kalıbını izle. `upsert` yalnızca girişli kullanıcıda çağrılır; misafirde hiçbir ağ çağrısı yapılmaz.

`meal_remote_datasource.dart` — öğün upsert payload'ına `'portion_grams': meal.portionGrams` ekle, `rowToEntity` okuma eşlemesine `portionGrams: row['portion_grams'] as int?`.

**Null-ezme koruması (Task 4 incelemesinden gelen zorunlu madde).** `meal_sync_service.dart`
bulut satırını `_local.saveMeal(MealRemoteDataSource.rowToEntity(...))` ile yerel satırın
üzerine yazıyor. Bu kolon eklendikten sonra bile **eski bulut satırlarında `portion_grams`
null** olacak — yani senkron, cihazda doğru duran gramajı null'la ezebilir. Koruma:
birleştirme sırasında uzaktan gelen `portionGrams` null ve yereldeki dolu ise, yereldeki
değer korunur.

Bunun testi zorunlu: yerelde `portionGrams: 350` olan bir öğün + uzaktan `portion_grams`
null gelen aynı `id` → senkron sonrası yerel değer hâlâ 350 olmalı. RED kontrolü yap
(korumayı kaldır → test kırmızı olmalı).

- [ ] **Step 4: Kaydetme yolunu bağla**

Sihirbaz kaydederken: her zaman yerel `save`, kullanıcı girişliyse ek olarak uzak `upsert`. Ağ hatası kullanıcıya hata göstermez — yerel kayıt kaynaktır, uzak kopya sonraki oturumda tekrar denenir. Hata `debugPrint` ile loglanır, sessizce yutulmaz.

- [ ] **Step 5: Run full suite**

```bash
flutter analyze --fatal-infos && flutter test
```

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations lib/features
git commit -m "feat(sync): olcum verisi ve porsiyon gramaji icin supabase kolonlari"
```

- [ ] **Step 7: Mağaza beyanı (kod değil — atlanamaz)**

Boy/kilo/yaş sağlık verisidir ve girişli kullanıcıda Supabase'e yazılır. Sürüm çıkmadan **önce** App Store Connect → App Privacy'ye **Health & Fitness → Body/Health data** eklenmeli (App Functionality, kimlikle ilişkili, tracking değil). 2026-08-13'te yayınlanan beyan bunu kapsamıyor. Play Console Data Safety formunda karşılığı: "Health and fitness → Health info".

---

## Doğrulama özeti

Plan tamamlandığında şunlar doğrulanmış olmalı:

- [ ] `flutter analyze --fatal-infos` temiz
- [ ] `flutter test` — mevcut 493 + ~30 yeni test geçiyor
- [ ] Metrics girilmemiş bir kurulumda besin tabloları bugünküyle bit bit aynı (100 g / 2000 kcal)
- [ ] Metrics girilmiş kullanıcıda öğün tablosu gerçek gramajı, yüzdelikler kişisel hedefi kullanıyor
- [ ] Misafirken girilen ölçüler kayıt sonrası hesaba taşınıyor, mevcut hesap verisi ezilmiyor
- [ ] 5 adımlı akış 720x1280 / density 320 emülatörde taşmıyor
- [ ] App Privacy beyanı güncellendi
