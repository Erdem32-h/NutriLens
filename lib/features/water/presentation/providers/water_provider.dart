import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../../profile/presentation/providers/user_metrics_provider.dart';
import '../../data/datasources/water_local_datasource.dart';
import '../../data/water_settings_store.dart';
import '../../domain/water_day.dart';
import '../../domain/water_goal.dart';
import '../../domain/water_reminder_schedule.dart';

/// Notification text, resolved by the caller from `context.l10n`.
typedef WaterReminderCopy = ({String title, String body});

final waterLocalDataSourceProvider = Provider<WaterLocalDataSource>(
  (ref) => WaterLocalDataSourceImpl(ref.watch(appDatabaseProvider)),
);

final waterSettingsStoreProvider = Provider<WaterSettingsStore>(
  (ref) => WaterSettingsStore(ref.watch(sharedPreferencesProvider)),
);

/// Test seam for "now".
final waterClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class WaterSettings {
  final int? customGoal;
  final bool reminderEnabled;

  const WaterSettings({
    required this.customGoal,
    required this.reminderEnabled,
  });
}

class WaterSettingsNotifier extends Notifier<WaterSettings> {
  WaterSettingsStore get _store => ref.read(waterSettingsStoreProvider);

  @override
  WaterSettings build() {
    final store = ref.watch(waterSettingsStoreProvider);
    return WaterSettings(
      customGoal: store.goal,
      reminderEnabled: store.reminderEnabled,
    );
  }

  Future<void> setGoal(int glasses) async {
    await _store.setGoal(glasses);
    state = WaterSettings(
      customGoal: _store.goal,
      reminderEnabled: state.reminderEnabled,
    );
  }

  Future<void> setReminderEnabled(bool enabled) async {
    await _store.setReminderEnabled(enabled);
    state = WaterSettings(
      customGoal: state.customGoal,
      reminderEnabled: enabled,
    );
  }
}

final waterSettingsProvider =
    NotifierProvider<WaterSettingsNotifier, WaterSettings>(
      WaterSettingsNotifier.new,
    );

/// Profile weight, or null. Separate so tests can await the metrics load.
final waterMetricsWeightProvider = FutureProvider<double?>((ref) async {
  final metrics = await ref.watch(userMetricsProvider.future);
  return metrics?.weightKg;
});

final waterGoalProvider = Provider<int>((ref) {
  final custom = ref.watch(waterSettingsProvider).customGoal;
  if (custom != null) return custom;
  return suggestedWaterGoal(ref.watch(waterMetricsWeightProvider).value);
});

final waterTodayProvider = FutureProvider<WaterDay>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  final goal = ref.watch(waterGoalProvider);
  final key = waterDayKey(ref.watch(waterClockProvider)());
  if (userId == null) return WaterDay(day: key, glasses: 0, goalGlasses: goal);
  final row = await ref.watch(waterLocalDataSourceProvider).getDay(userId, key);
  return row ?? WaterDay(day: key, glasses: 0, goalGlasses: goal);
});

final waterWeekProvider = FutureProvider<List<WaterDay>>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  final goal = ref.watch(waterGoalProvider);
  final now = ref.watch(waterClockProvider)();
  final keys = [
    for (var i = 6; i >= 0; i--)
      waterDayKey(DateTime(now.year, now.month, now.day - i)),
  ];
  final rows = userId == null
      ? const <WaterDay>[]
      : await ref
            .watch(waterLocalDataSourceProvider)
            .getRange(userId: userId, fromDay: keys.first, toDay: keys.last);
  final byDay = {for (final row in rows) row.day: row};
  return [
    for (final key in keys)
      byDay[key] ?? WaterDay(day: key, glasses: 0, goalGlasses: goal),
  ];
});

/// Single write path for water data: Drift → invalidate → analytics →
/// reminders. Reminder failures never fail the write.
class WaterController {
  final Ref _ref;

  WaterController(this._ref);

  WaterLocalDataSource get _ds => _ref.read(waterLocalDataSourceProvider);
  NotificationService get _notifications =>
      _ref.read(notificationServiceProvider);
  DateTime _now() => _ref.read(waterClockProvider)();

  void _invalidate() {
    _ref.invalidate(waterTodayProvider);
    _ref.invalidate(waterWeekProvider);
  }

  Future<WaterDay?> addGlass(WaterReminderCopy copy) async {
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId == null) {
      await rescheduleReminders(copy);
      return null;
    }
    final day = await _ds.addGlass(
      userId: userId,
      now: _now(),
      goal: _ref.read(waterGoalProvider),
    );
    _invalidate();
    _ref.read(analyticsServiceProvider).track(FunnelEvents.waterGlassAdded);
    await rescheduleReminders(copy);
    return day;
  }

  Future<WaterDay?> removeGlass(WaterReminderCopy copy) async {
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId == null) return null;
    final day = await _ds.removeGlass(
      userId: userId,
      now: _now(),
      goal: _ref.read(waterGoalProvider),
    );
    _invalidate();
    await rescheduleReminders(copy);
    return day;
  }

  Future<void> setGoal(int glasses, WaterReminderCopy copy) async {
    await _ref.read(waterSettingsProvider.notifier).setGoal(glasses);
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId != null) {
      await _ds.setGoalForDay(
        userId: userId,
        day: waterDayKey(_now()),
        goal: _ref.read(waterGoalProvider),
      );
    }
    _invalidate();
    await rescheduleReminders(copy);
  }

  /// False only when the OS permission was denied.
  Future<bool> setReminderEnabled(bool enabled, WaterReminderCopy copy) async {
    final settings = _ref.read(waterSettingsProvider.notifier);
    if (!enabled) {
      await settings.setReminderEnabled(false);
      await rescheduleReminders(copy);
      return true;
    }
    if (!await _notifications.requestPermission()) return false;
    await settings.setReminderEnabled(true);
    _ref
        .read(analyticsServiceProvider)
        .track(FunnelEvents.waterReminderEnabled);
    await rescheduleReminders(copy);
    return true;
  }

  Future<void> rescheduleReminders(WaterReminderCopy copy) async {
    try {
      final userId = _ref.read(effectiveUserIdProvider);
      if (userId == null || !_ref.read(waterSettingsProvider).reminderEnabled) {
        await _notifications.cancelWaterReminders();
        return;
      }
      final now = _now();
      final goal = _ref.read(waterGoalProvider);
      final today = await _ds.getDay(userId, waterDayKey(now));
      await _notifications.rescheduleWaterReminders(
        times: waterReminderTimes(
          now: now,
          lastGlassAt: today?.lastGlassAt,
          glassesToday: today?.glasses ?? 0,
          goal: goal,
        ),
        title: copy.title,
        body: copy.body,
      );
    } catch (e) {
      debugPrint('[Water] reminder reschedule failed: $e');
    }
  }
}

final waterControllerProvider = Provider<WaterController>(WaterController.new);
