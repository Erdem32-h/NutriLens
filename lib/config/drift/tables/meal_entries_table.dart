import 'package:drift/drift.dart';

class MealEntries extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get photoThumbnailPath => text().nullable()();
  TextColumn get mealName => text()();
  TextColumn get brand => text().withDefault(const Constant('Ev yapımı'))();
  TextColumn get mealType => text()();
  DateTimeColumn get capturedAt => dateTime()();
  TextColumn get ingredientsText => text().nullable()();
  TextColumn get nutriments => text().withDefault(const Constant('{}'))();
  RealColumn get calories => real().withDefault(const Constant(0))();
  RealColumn get hpScore => real().nullable()();
  RealColumn get confidence => real().nullable()();
  TextColumn get aiRawJson => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('local_only'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
