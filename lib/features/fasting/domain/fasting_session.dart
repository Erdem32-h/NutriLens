/// A single fasting attempt: started, optionally ended, targeting
/// [targetMinutes] of fasting.
class FastingSession {
  final String id;
  final String userId;
  final DateTime startedAt;
  final int targetMinutes;
  final DateTime? endedAt;

  const FastingSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.targetMinutes,
    this.endedAt,
  });

  /// True while the fast has not been ended yet.
  bool get isActive => endedAt == null;

  /// Time elapsed since [startedAt], up to [endedAt] if the fast has ended,
  /// otherwise up to [now].
  Duration elapsed(DateTime now) => (endedAt ?? now).difference(startedAt);

  /// Time left until [targetMinutes] is reached as of [now]; never negative.
  Duration remaining(DateTime now) {
    final left = Duration(minutes: targetMinutes) - elapsed(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Fraction of [targetMinutes] reached as of [now], clamped to 0..1.
  double progress(DateTime now) {
    final targetMs = Duration(minutes: targetMinutes).inMilliseconds;
    if (targetMs <= 0) return 1.0;
    return (elapsed(now).inMilliseconds / targetMs).clamp(0.0, 1.0);
  }

  /// Whether [targetMinutes] has been reached as of [now].
  bool reachedTarget(DateTime now) =>
      elapsed(now) >= Duration(minutes: targetMinutes);

  /// Ended, and its actual duration reached [targetMinutes].
  bool get isCompleted {
    final end = endedAt;
    if (end == null) return false;
    return end.difference(startedAt) >= Duration(minutes: targetMinutes);
  }
}
