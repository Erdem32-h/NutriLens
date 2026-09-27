import 'package:nutrilens/features/ramadan/domain/fasting_times.dart';
import 'package:nutrilens/features/water/domain/water_reminder_schedule.dart'
    show waterReminderGap, waterReminderHours, todaySlotFilter;

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

/// The normal (non-Ramadan) `waterReminderHours` slots for [day].
List<DateTime> _normalSlots(DateTime day) => [
  for (final hour in waterReminderHours) DateTime(day.year, day.month, day.day, hour),
];

/// Water reminder times for today (remaining) and tomorrow (all slots),
/// mirroring `waterReminderTimes`: today's slots are dropped once they're
/// in the past, silenced for [waterReminderGap] after the last glass (if
/// drunk today), and skipped entirely once [goal] is met. Tomorrow's slots
/// are always included. Capped at 14 total.
///
/// Decided per day: a day with [FastingTimes] (a Ramadan day) gets the
/// iftar-window slots, a null day (offer window before day 1, or Eid) gets
/// the normal `waterReminderHours`.
List<DateTime> ramadanWaterTimes({
  required DateTime now,
  required FastingTimes? today,
  required FastingTimes? tomorrow,
  required DateTime? lastGlassAt,
  required int glassesToday,
  required int goal,
}) {
  final isTodaySlot = todaySlotFilter(now: now, lastGlassAt: lastGlassAt);

  final todaySlots = <DateTime>[
    if (glassesToday < goal) ...today != null ? _daySlots(today) : _normalSlots(now),
  ].where(isTodaySlot);
  final tomorrowSlots = tomorrow != null
      ? _daySlots(tomorrow)
      : _normalSlots(DateTime(now.year, now.month, now.day + 1));

  final result = [...todaySlots, ...tomorrowSlots];
  return result.length > _ramadanWaterMaxSlots ? result.sublist(0, _ramadanWaterMaxSlots) : result;
}

enum RamadanNotificationKind { sahur, iftar }

/// A single scheduled sahur or iftar notification. [imsakAt] is that day's
/// imsak instant — set for sahur notifications (the body states it
/// verbatim so a late-firing inexact alarm never implies more time is
/// left than there is, see D2), null for iftar.
typedef RamadanNotification = ({
  int id,
  DateTime at,
  RamadanNotificationKind kind,
  DateTime? imsakAt,
});

/// Civil (year/month/day) key for date comparisons that must ignore the
/// instant/timezone a `DateTime` was built with — see `RamadanPeriod`.
int _civilDateKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Sahur (imsak - [sahurOffsetMin]) and iftar notifications for each day in
/// [nextDays], skipping days before [firstDay] (the offer window) or on/after
/// [eidDay], and any notification that
/// has already passed [now]. Day `i` in the list gets ids `3000 + i`
/// (sahur) and `3010 + i` (iftar) — [nextDays] must be at most 7 entries so
/// ids stay within the 3000–3006 / 3010–3016 range reserved for this feature.
List<RamadanNotification> ramadanNotificationTimes({
  required DateTime now,
  required List<(DateTime day, FastingTimes times)> nextDays,
  required int sahurOffsetMin,
  required DateTime firstDay,
  required DateTime eidDay,
}) {
  assert(nextDays.length <= 7, 'nextDays must be at most 7 days (ids stay within 3000-3006/3010-3016)');
  final firstKey = _civilDateKey(firstDay);
  final eidKey = _civilDateKey(eidDay);
  final result = <RamadanNotification>[];

  for (var i = 0; i < nextDays.length; i++) {
    final (day, times) = nextDays[i];
    final key = _civilDateKey(day);
    if (key < firstKey || key >= eidKey) continue;

    final sahurAt = times.imsak.subtract(Duration(minutes: sahurOffsetMin));
    if (sahurAt.isAfter(now)) {
      result.add((
        id: 3000 + i,
        at: sahurAt,
        kind: RamadanNotificationKind.sahur,
        imsakAt: times.imsak,
      ));
    }
    if (times.iftar.isAfter(now)) {
      result.add((
        id: 3010 + i,
        at: times.iftar,
        kind: RamadanNotificationKind.iftar,
        imsakAt: null,
      ));
    }
  }

  return result;
}
