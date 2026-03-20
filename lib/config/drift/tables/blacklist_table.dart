import 'package:drift/drift.dart';

@DataClassName('BlacklistEntry')
class Blacklist extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get barcode => text()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get addedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, barcode},
      ];
}
