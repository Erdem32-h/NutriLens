import 'package:drift/drift.dart';

class CounterfeitProducts extends Table {
  TextColumn get id => text()();
  TextColumn get brandName => text()();
  TextColumn get productName => text()();
  TextColumn get category => text().nullable()();
  TextColumn get violationType => text()();
  TextColumn get violationDetail => text().nullable()();
  TextColumn get province => text().nullable()();
  DateTimeColumn get detectionDate => dateTime().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get syncedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
