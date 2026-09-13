/// Local calendar day as stored in `water_logs.day`.
String waterDayKey(DateTime local) {
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

class WaterDay {
  final String day;
  final int glasses;

  /// Goal as it was on [day] — see `WaterLogs.goalGlasses`.
  final int goalGlasses;
  final DateTime? lastGlassAt;

  const WaterDay({
    required this.day,
    required this.glasses,
    required this.goalGlasses,
    this.lastGlassAt,
  });

  bool get goalMet => glasses >= goalGlasses;
}
