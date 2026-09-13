import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the daily "log a meal" reminder.
///
/// Always a one-shot [zonedSchedule], never an OS-level repeating trigger:
/// a repeating alarm has no clean way to skip a single day, so instead the
/// caller recomputes and reschedules on every relevant event —
/// [rescheduleDailyReminder] cancels whatever is pending and, unless the
/// user already logged a meal today, arms exactly one future notification
/// for the next upcoming 19:00. Call it after every meal save
/// (`mealLoggedToday: true` — skip today, arm tomorrow) and once per app
/// launch (`mealLoggedToday`: computed from local data — covers the case
/// where a previous day's reminder already fired and nothing re-armed it).
class NotificationService {
  static const _reminderId = 1001;
  static const _reminderHour = 19;
  static const _channelId = 'daily_meal_reminder';
  static const _channelName = 'Öğün Hatırlatma';

  static const _waterChannelId = 'water_reminder';
  static const _waterChannelName = 'Su Hatırlatma';
  static const _waterBaseId = 2000;

  /// Today's remaining slots + tomorrow's 7 (see `waterReminderTimes`).
  static const _waterMaxCount = 14;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _tzReady = false;

  NotificationService(this._plugin);

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );
  }

  /// idempotent — safe to call from every code path that needs a correct
  /// [tz.local] without each one tracking init order itself.
  Future<void> _ensureTimezone() async {
    if (_tzReady) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Unrecognised platform identifier — falls back to UTC. Only DST
      // transitions drift by an hour then; the day the reminder lands on
      // is still correct, which is the part that matters here.
      tz.setLocalLocation(tz.UTC);
    }
    _tzReady = true;
  }

  /// Requests OS notification permission and reports whether it is granted.
  /// Both platforms show their system dialog at most once per install
  /// regardless of call count — callers still gate this behind their own
  /// one-shot flag (see `NotificationPromptStore`) so the ask happens at a
  /// deliberate moment rather than on every app launch.
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  /// Cancels any pending reminder and, unless [mealLoggedToday], arms a
  /// fresh one-shot for the next 19:00 that hasn't passed yet (today's if
  /// it's still ahead, otherwise tomorrow's).
  Future<void> rescheduleDailyReminder({
    required bool mealLoggedToday,
    required String title,
    required String body,
  }) async {
    await _plugin.cancel(id: _reminderId);
    if (mealLoggedToday) return;

    await _ensureTimezone();
    final now = tz.TZDateTime.now(tz.local);
    var target = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      _reminderHour,
    );
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _reminderId,
      title: title,
      body: body,
      scheduledDate: target,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Replaces every pending water reminder with [times] (wall-clock, local).
  /// Ids are sequential from 2000 so a shorter list never leaves stale
  /// reminders behind — all 14 ids are cancelled first.
  Future<void> rescheduleWaterReminders({
    required List<DateTime> times,
    required String title,
    required String body,
  }) async {
    await cancelWaterReminders();
    if (times.isEmpty) return;

    await _ensureTimezone();
    final count = times.length < _waterMaxCount ? times.length : _waterMaxCount;
    for (var i = 0; i < count; i++) {
      final t = times[i];
      await _plugin.zonedSchedule(
        id: _waterBaseId + i,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime(
          tz.local,
          t.year,
          t.month,
          t.day,
          t.hour,
          t.minute,
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _waterChannelId,
            _waterChannelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  Future<void> cancelWaterReminders() async {
    for (var i = 0; i < _waterMaxCount; i++) {
      await _plugin.cancel(id: _waterBaseId + i);
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FlutterLocalNotificationsPlugin());
});
