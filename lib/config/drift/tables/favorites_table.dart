import 'package:drift/drift.dart';

@DataClassName('FavoriteEntry')
class Favorites extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get barcode => text()();
  DateTimeColumn get addedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, barcode},
      ];
}
