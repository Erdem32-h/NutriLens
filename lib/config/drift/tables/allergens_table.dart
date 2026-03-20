import 'package:drift/drift.dart';

class Allergens extends Table {
  TextColumn get id => text()();
  TextColumn get nameEn => text()();
  TextColumn get nameTr => text()();
  TextColumn get category => text().nullable()();
  TextColumn get iconName => text().nullable()();
  TextColumn get severityNote => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
