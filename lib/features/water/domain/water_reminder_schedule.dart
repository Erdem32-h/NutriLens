const waterReminderHours = [9, 11, 13, 15, 17, 19, 21];

/// Minimum quiet time after a glass before the next reminder slot.
const waterReminderGap = Duration(hours: 2);

/// Predicate that keeps only today's still-actionable slots: drops any
/// slot at or before [now], and — if the last glass was drunk today —
/// silences slots within [waterReminderGap] after [lastGlassAt].
///
/// Shared by `waterReminderTimes` and `ramadanWaterTimes` so both features'
/// "today" rules stay identical.
bool Function(DateTime slot) todaySlotFilter({
  required DateTime now,
  required DateTime? lastGlassAt,
}) {
  final lastToday =
      lastGlassAt != null &&
      lastGlassAt.year == now.year &&
      lastGlassAt.month == now.month &&
      lastGlassAt.day == now.day;
  final quietUntil = lastToday ? lastGlassAt.add(waterReminderGap) : null;

  return (slot) {
    if (!slot.isAfter(now)) return false;
    return quietUntil == null || !slot.isBefore(quietUntil);
  };
}

/// Reminder times for today (remaining) and tomorrow (all slots).
///
/// Wall-clock values built with the `DateTime` constructor — never
/// `add(Duration(days: 1))` — so a DST night still yields 09:00..21:00.
/// The notification layer converts them to `tz.local`.
List<DateTime> waterReminderTimes({
  required DateTime now,
  required DateTime? lastGlassAt,
  required int glassesToday,
  required int goal,
}) {
  final isTodaySlot = todaySlotFilter(now: now, lastGlassAt: lastGlassAt);

  final today =
      <DateTime>[
        if (glassesToday < goal)
          for (final hour in waterReminderHours)
            DateTime(now.year, now.month, now.day, hour),
      ].where(isTodaySlot);

  final tomorrow = [
    for (final hour in waterReminderHours)
      DateTime(now.year, now.month, now.day + 1, hour),
  ];

  return [...today, ...tomorrow];
}
