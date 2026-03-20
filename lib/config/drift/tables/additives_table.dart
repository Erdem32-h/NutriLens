import 'package:drift/drift.dart';

class Additives extends Table {
  TextColumn get id => text()();
  TextColumn get eNumber => text()();
  TextColumn get nameEn => text()();
  TextColumn get nameTr => text().nullable()();
  TextColumn get category => text()();
  IntColumn get riskLevel => integer()();
  TextColumn get riskLabel => text()();
  TextColumn get descriptionEn => text().nullable()();
  TextColumn get descriptionTr => text().nullable()();
  TextColumn get efsaStatus => text().nullable()();
  TextColumn get turkishCodexStatus => text().nullable()();
  TextColumn get maxDailyIntake => text().nullable()();
  TextColumn get source => text().nullable()();
  BoolColumn get isVegan => boolean().withDefault(const Constant(true))();
  BoolColumn get isVegetarian =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get isHalal => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
