import 'package:drift/drift.dart';

class ScanHistory extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get barcode => text()();
  DateTimeColumn get scannedAt =>
      dateTime().withDefault(currentDateAndTime)();
  RealColumn get hpScoreAtScan => real().nullable()();
  TextColumn get compatibilityResult =>
      text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
