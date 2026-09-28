import 'fasting_session.dart';

/// Local calendar day of [dt] as a DST-safe UTC key (mirrors the approach in
/// `ramadan_calendar.dart`'s `_dateToUtc`).
DateTime _dayKey(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

/// Consecutive-day fasting streak counting back from today (or yesterday if
/// today has no completed fast yet), based on the local day each fast ended.
int fastingStreak(List<FastingSession> sessions, DateTime now) {
  final completedDays = <DateTime>{
    for (final s in sessions)
      if (s.isCompleted) _dayKey(s.endedAt!),
  };

  var cursor = _dayKey(now);
  if (!completedDays.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!completedDays.contains(cursor)) return 0;
  }

  var streak = 0;
  while (completedDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Average elapsed duration of the 30 most recently completed fasts (by
/// [FastingSession.endedAt]), or null if there are none.
Duration? averageFastDuration(List<FastingSession> sessions) {
  final completed = sessions.where((s) => s.isCompleted).toList()
    ..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));
  if (completed.isEmpty) return null;

  final recent = completed.take(30);
  final totalMicros = recent.fold<int>(
    0,
    (sum, s) => sum + s.endedAt!.difference(s.startedAt).inMicroseconds,
  );
  return Duration(microseconds: totalMicros ~/ recent.length);
}
