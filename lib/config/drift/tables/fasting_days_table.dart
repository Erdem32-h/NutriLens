import 'package:drift/drift.dart';

/// Oruç tutulan günler — kullanıcı + gün başına tek satır.
///
/// Satırın varlığı o gün oruç tutulduğu anlamına gelir; işareti kaldırmak
/// satırı siler. `day` yerel tarih (`yyyy-MM-dd`). Misafirde
/// `userId == kGuestUserId`, tıpkı `water_logs` gibi.
class FastingDays extends Table {
  TextColumn get userId => text()();
  TextColumn get day => text()();

  @override
  Set<Column> get primaryKey => {userId, day};
}
