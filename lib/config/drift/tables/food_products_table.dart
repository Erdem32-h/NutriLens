import 'package:drift/drift.dart';

class FoodProducts extends Table {
  TextColumn get barcode => text()();
  TextColumn get productName => text().nullable()();
  TextColumn get brands => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get ingredientsText => text().nullable()();
  TextColumn get allergensTags => text().withDefault(const Constant('[]'))();
  TextColumn get additivesTags => text().withDefault(const Constant('[]'))();
  IntColumn get novaGroup => integer().nullable()();
  TextColumn get nutriscoreGrade => text().nullable()();
  TextColumn get nutriments => text().withDefault(const Constant('{}'))();
  TextColumn get categoriesTags => text().withDefault(const Constant('[]'))();
  TextColumn get countriesTags => text().withDefault(const Constant('[]'))();
  RealColumn get hpScore => real().nullable()();
  RealColumn get hpChemicalLoad => real().nullable()();
  RealColumn get hpRiskFactor => real().nullable()();
  RealColumn get hpNutriFactor => real().nullable()();
  DateTimeColumn get cachedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {barcode};
}
