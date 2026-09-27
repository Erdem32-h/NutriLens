import 'package:adhan_dart/adhan_dart.dart';

/// Imsak (fajr) and iftar (maghrib) for a given day, device-local, whole minutes.
typedef FastingTimes = ({DateTime imsak, DateTime iftar});

/// Computes imsak/iftar for [date] (calendar day only) at [lat]/[lng] using the
/// Diyanet calculation method. Imsak is floored and iftar is ceiled to the
/// minute so fasting windows never run short.
FastingTimes fastingTimes(DateTime date, double lat, double lng) {
  final params = CalculationMethodParameters.turkiye()..rounding = Rounding.none;
  final times = PrayerTimes(
    date: date,
    coordinates: Coordinates(lat, lng),
    calculationParameters: params,
  );
  return (
    imsak: floorToMinute(times.fajr.toLocal()),
    iftar: ceilToMinute(times.maghrib.toLocal()),
  );
}

/// Truncates [t] down to the start of its minute.
DateTime floorToMinute(DateTime t) => DateTime(t.year, t.month, t.day, t.hour, t.minute);

/// Rounds [t] up to the next minute, unless it already falls exactly on one.
DateTime ceilToMinute(DateTime t) {
  final floored = floorToMinute(t);
  return t.isAfter(floored) ? floored.add(const Duration(minutes: 1)) : floored;
}
