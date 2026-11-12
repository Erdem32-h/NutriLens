/// At most four nudges a day. Fewer, well-spaced slots are a reminder, not
/// pressure; today's slots are further cut by [expectedGlassesBy].
const waterReminderHours = [10, 13, 16, 19];

/// Glasses a steady drinker would have had by [hour], spreading [goal]
/// over 08:00–20:00. A slot only fires for someone below this, so a user
/// who is on pace is left alone.
int expectedGlassesBy(int hour, int goal) => (goal * (hour - 8) / 12).ceil();

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

/// Reminder times for today (remaining, behind-pace only) and tomorrow
/// (all slots). Nothing past tomorrow is armed: someone who stops opening
/// the app stops getting reminders after one day.
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

  final today = <DateTime>[
    if (glassesToday < goal)
      for (final hour in waterReminderHours)
        if (glassesToday < expectedGlassesBy(hour, goal))
          DateTime(now.year, now.month, now.day, hour),
  ].where(isTodaySlot);

  final tomorrow = [
    for (final hour in waterReminderHours)
      DateTime(now.year, now.month, now.day + 1, hour),
  ];

  return [...today, ...tomorrow];
}
