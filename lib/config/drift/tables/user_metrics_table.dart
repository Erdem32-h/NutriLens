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
