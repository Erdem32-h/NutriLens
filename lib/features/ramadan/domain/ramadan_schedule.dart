import 'package:nutrilens/features/ramadan/domain/fasting_times.dart';
import 'package:nutrilens/features/water/domain/water_reminder_schedule.dart' show waterReminderGap;

/// How long after iftar the first Ramadan water reminder fires.
const _ramadanWaterAfterIftar = Duration(minutes: 30);

/// Latest minute-of-day a Ramadan water reminder may fire (23:30).
const _ramadanWaterCutoffMinutes = 23 * 60 + 30;

/// Cap on the number of slots `ramadanWaterTimes` can return.
const _ramadanWaterMaxSlots = 14;

/// Water reminder slots for one day: iftar + 30 min, then every
/// [waterReminderGap] up to (and including) 23:30. Built with the
/// `DateTime(y, m, d, h, min)` constructor so DST never shifts the slot.
List<DateTime> _daySlots(FastingTimes times) {
  final iftar = times.iftar;
  final slots = <DateTime>[];
  var minuteOfDay = iftar.hour * 60 + iftar.minute + _ramadanWaterAfterIftar.inMinutes;
  while (minuteOfDay <= _ramadanWaterCutoffMinutes) {
    slots.add(DateTime(iftar.year, iftar.month, iftar.day, minuteOfDay ~/ 60, minuteOfDay % 60));
    minuteOfDay += waterReminderGap.inMinutes;
  }
  return slots;
}

/// Ramadan water reminder times for today (remaining) and tomorrow (all
/// slots), mirroring `waterReminderTimes`: today's slots are dropped once
/// they're in the past, silenced for [waterReminderGap] after the last
/// glass (if drunk today), and skipped entirely once [goal] is met.
/// Tomorrow's slots are always included. Capped at 14 total.
List<DateTime> ramadanWaterTimes({
  required DateTime now,
  required FastingTimes today,
  required FastingTimes tomorrow,
  required DateTime? lastGlassAt,
  required int glassesToday,
  required int goal,
}) {
  final lastToday =
      lastGlassAt != null &&
      lastGlassAt.year == now.year &&
      lastGlassAt.month == now.month &&
      lastGlassAt.day == now.day;
  final quietUntil = lastToday ? lastGlassAt.add(waterReminderGap) : null;

  final todaySlots = <DateTime>[
    if (glassesToday < goal) ..._daySlots(today),
  ].where((slot) {
    if (!slot.isAfter(now)) return false;
    return quietUntil == null || !slot.isBefore(quietUntil);
  });

  final result = [...todaySlots, ..._daySlots(tomorrow)];
  return result.length > _ramadanWaterMaxSlots ? result.sublist(0, _ramadanWaterMaxSlots) : result;
}

enum RamadanNotificationKind { sahur, iftar }

/// A single scheduled sahur or iftar notification.
typedef RamadanNotification = ({int id, DateTime at, RamadanNotificationKind kind});

/// Civil (year/month/day) key for date comparisons that must ignore the
/// instant/timezone a `DateTime` was built with — see `RamadanPeriod`.
int _civilDateKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Sahur (imsak - [sahurOffsetMin]) and iftar notifications for each day in
/// [nextDays], skipping days on or after [eidDay] and any notification that
/// has already passed [now]. Day `i` in the list gets ids `3000 + i`
/// (sahur) and `3010 + i` (iftar).
List<RamadanNotification> ramadanNotificationTimes({
  required DateTime now,
  required List<(DateTime day, FastingTimes times)> nextDays,
  required int sahurOffsetMin,
  required DateTime eidDay,
}) {
  final eidKey = _civilDateKey(eidDay);
  final result = <RamadanNotification>[];

  for (var i = 0; i < nextDays.length; i++) {
    final (day, times) = nextDays[i];
    if (_civilDateKey(day) >= eidKey) continue;

    final sahurAt = times.imsak.subtract(Duration(minutes: sahurOffsetMin));
    if (sahurAt.isAfter(now)) {
      result.add((id: 3000 + i, at: sahurAt, kind: RamadanNotificationKind.sahur));
    }
    if (times.iftar.isAfter(now)) {
      result.add((id: 3010 + i, at: times.iftar, kind: RamadanNotificationKind.iftar));
    }
  }

  return result;
}
