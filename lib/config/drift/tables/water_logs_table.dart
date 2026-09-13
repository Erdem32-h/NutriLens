import 'package:drift/drift.dart';

/// Günlük su sayacı — kullanıcı + gün başına tek satır.
///
/// `day` yerel tarih (`yyyy-MM-dd`). `goalGlasses` o günün hedefinin kopyası:
/// hedef sonradan değişse de geçmiş bir günün "hedefe ulaşıldı mı" sonucu
/// değişmesin. Misafirde `userId == kGuestUserId`.
class WaterLogs extends Table {
  TextColumn get userId => text()();
  TextColumn get day => text()();
  IntColumn get glasses => integer().withDefault(const Constant(0))();
  IntColumn get goalGlasses => integer()();
  DateTimeColumn get lastGlassAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {userId, day};
}
