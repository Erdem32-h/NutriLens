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

  test(
    'bozuk enum metni cokmez, guvenli varsayilana duser',
    () async {
      // Elle bozuk bir satir yaz — entity katmanindan degil, dogrudan
      // Drift'e. Uygulama disi bir surecin (elle DB duzenleme, eski surum
      // migration'i) beklenmedik bir metin birakmasini simule ediyor.
      await db
          .into(db.userMetrics)
          .insertOnConflictUpdate(
            UserMetricsCompanion.insert(
              userId: 'corrupted',
              sex: 'not-a-real-sex',
              birthYear: 1990,
              heightCm: 170,
              weightKg: 70,
              activityLevel: 'not-a-real-activity',
              updatedAt: DateTime(2026, 8, 14),
            ),
          );

      final read = await ds.get('corrupted');

      expect(read, isNotNull);
      expect(read!.sex, BiologicalSex.unspecified);
      expect(read.activity, ActivityLevel.sedentary);
    },
  );
}
