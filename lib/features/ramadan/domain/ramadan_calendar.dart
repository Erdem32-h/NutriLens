import 'package:nutrilens/features/water/domain/water_day.dart';

/// Represents a Ramadan period: first day through Eid.
class RamadanPeriod {
  final DateTime firstDay;
  final DateTime eidDay;

  const RamadanPeriod({
    required this.firstDay,
    required this.eidDay,
  });

  /// Number of days in this Ramadan period.
  int get length => eidDay.difference(firstDay).inDays;

  /// Gregorian year of the first day.
  int get year => firstDay.year;
}

/// Ramadan 1448–1449 AH (2026–2028 CE).
/// Source: Diyanet (Turkish Presidency of Religious Affairs).
final ramadanPeriods = [
  // Ramadan 1448 AH → 29 days (source: Diyanet).
  RamadanPeriod(
    firstDay: DateTime.utc(2027, 2, 8),
    eidDay: DateTime.utc(2027, 3, 9),
  ),
];

/// Normalize DateTime to UTC date only (ignoring time and timezone).
DateTime _dateToUtc(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

/// Returns the Ramadan period currently active (between firstDay and eidDay) or null.
RamadanPeriod? currentRamadan(DateTime now) {
  final dateUtc = _dateToUtc(now);
  for (final period in ramadanPeriods) {
    if (!dateUtc.isBefore(period.firstDay) && dateUtc.isBefore(period.eidDay)) {
      return period;
    }
  }
  return null;
}

/// Returns the Ramadan offer period: from [firstDay - 3 days] to before [eidDay].
/// Returns null if [now] is outside any offer window.
RamadanPeriod? offerPeriod(DateTime now) {
  final dateUtc = _dateToUtc(now);
  for (final period in ramadanPeriods) {
    final offerStart = DateTime.utc(
      period.firstDay.year,
      period.firstDay.month,
      period.firstDay.day - 3,
    );
    if (!dateUtc.isBefore(offerStart) && dateUtc.isBefore(period.eidDay)) {
      return period;
    }
  }
  return null;
}

/// Returns the most recent Ramadan period whose firstDay <= now, or null.
RamadanPeriod? latestPeriod(DateTime now) {
  final dateUtc = _dateToUtc(now);
  RamadanPeriod? latest;
  for (final period in ramadanPeriods) {
    if (!dateUtc.isBefore(period.firstDay)) {
      latest = period;
    }
  }
  return latest;
}

/// Returns the 1-based day of Ramadan if [now] is within the current Ramadan, or null.
int? ramadanDayIndex(DateTime now) {
  final period = currentRamadan(now);
  if (period == null) return null;
  final dateUtc = _dateToUtc(now);
  return dateUtc.difference(period.firstDay).inDays + 1;
}

/// Local calendar day as stored in the Ramadan logs.
String ramadanDayKey(DateTime d) => waterDayKey(d);
