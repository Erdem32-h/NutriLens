import 'package:drift/drift.dart';

/// A single fasting attempt: started, optionally ended, targeting a
/// duration in minutes picked from the protocol at start time.
///
/// At most one row with `endedAt == null` per user is allowed (enforced in
/// the datasource, not the schema). `userId == kGuestUserId` for guests,
/// same convention as `fasting_days`.
///
/// Named explicitly to avoid colliding with the domain `FastingSession`
/// class — Drift would otherwise singularize the table name to the same
/// identifier for the generated row class.
@DataClassName('FastingSessionRow')
class FastingSessions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get targetMinutes => integer()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
