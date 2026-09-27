import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../../water/presentation/providers/water_provider.dart';
import '../../data/fasting_days_local_datasource.dart';
import '../../data/ramadan_settings_store.dart';
import '../../domain/fasting_times.dart';
import '../../domain/ramadan_calendar.dart';
import '../../domain/ramadan_schedule.dart';
import '../ramadan_actions.dart';

final ramadanSettingsStoreProvider = Provider<RamadanSettingsStore>(
  (ref) => RamadanSettingsStore(ref.watch(sharedPreferencesProvider)),
);

final fastingDaysLocalDataSourceProvider =
    Provider<FastingDaysLocalDataSource>(
      (ref) => FastingDaysLocalDataSourceImpl(ref.watch(appDatabaseProvider)),
    );

/// Test seam for "now".
final ramadanClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Whether the OS currently permits local notifications — backs the
/// countdown card's "Bildirimler kapalı — aç" nudge. Invalidate after a
/// permission request to re-check without restarting the app; doesn't
/// itself show the system dialog (see `NotificationService.requestPermission`
/// for that).
final notificationsPermittedProvider = FutureProvider<bool>(
  (ref) => ref.read(notificationServiceProvider).notificationsPermitted(),
);

class RamadanState {
  final bool enabled;

  /// Null unless lat, lng and label are all present — see
  /// `RamadanSettingsStore.location`.
  final ({double lat, double lng, String label, int? plate})? location;
  final int sahurOffsetMin;
  final int? offerDismissedYear;

  const RamadanState({
    required this.enabled,
    required this.location,
    required this.sahurOffsetMin,
    required this.offerDismissedYear,
  });
}

class RamadanSettingsNotifier extends Notifier<RamadanState> {
  RamadanSettingsStore get _store => ref.read(ramadanSettingsStoreProvider);

  @override
  RamadanState build() {
    final store = ref.watch(ramadanSettingsStoreProvider);
    return RamadanState(
      enabled: store.enabled,
      location: store.location,
      sahurOffsetMin: store.sahurOffsetMin,
      offerDismissedYear: store.offerDismissedYear,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    await _store.setEnabled(enabled);
    state = RamadanState(
      enabled: enabled,
      location: state.location,
      sahurOffsetMin: state.sahurOffsetMin,
      offerDismissedYear: state.offerDismissedYear,
    );
  }

  Future<void> setLocation({
    required double lat,
    required double lng,
    required String label,
    int? plate,
  }) async {
    await _store.setLocation(lat: lat, lng: lng, label: label, plate: plate);
    state = RamadanState(
      enabled: state.enabled,
      location: _store.location,
      sahurOffsetMin: state.sahurOffsetMin,
      offerDismissedYear: state.offerDismissedYear,
    );
  }

  Future<void> setSahurOffsetMin(int minutes) async {
    await _store.setSahurOffsetMin(minutes);
    state = RamadanState(
      enabled: state.enabled,
      location: state.location,
      sahurOffsetMin: minutes,
      offerDismissedYear: state.offerDismissedYear,
    );
  }

  Future<void> dismissOffer(int year) async {
    await _store.dismissOffer(year);
    state = RamadanState(
      enabled: state.enabled,
      location: state.location,
      sahurOffsetMin: state.sahurOffsetMin,
      offerDismissedYear: year,
    );
  }
}

final ramadanSettingsProvider =
    NotifierProvider<RamadanSettingsNotifier, RamadanState>(
      RamadanSettingsNotifier.new,
    );

/// Days of `latestPeriod` the user marked as fasted.
final fastingDaysProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  final period = latestPeriod(ref.watch(ramadanClockProvider)());
  if (userId == null || period == null) return {};
  return ref
      .watch(fastingDaysLocalDataSourceProvider)
      .getDays(
        userId,
        from: ramadanDayKey(period.firstDay),
        toExclusive: ramadanDayKey(period.eidDay),
      );
});

/// Single write path for Ramadan settings/fasting-day data: store →
/// invalidate → analytics → notifications/water reminders. Notification
/// failures never fail the write — mirrors `WaterController`.
class RamadanController {
  final Ref _ref;

  RamadanController(this._ref);

  RamadanSettingsNotifier get _settings =>
      _ref.read(ramadanSettingsProvider.notifier);
  NotificationService get _notifications =>
      _ref.read(notificationServiceProvider);
  DateTime _now() => _ref.read(ramadanClockProvider)();

  Future<void> enable({
    required double lat,
    required double lng,
    required String label,
    int? plate,
    required String source,
    required RamadanCopy copy,
    required WaterReminderCopy waterCopy,
  }) async {
    // Ask for notification permission (spec §5 step 2) but enable whatever
    // the answer — the countdown card's "Bildirimler kapalı — aç" link
    // covers a denial.
    try {
      await _notifications.requestPermission();
    } catch (e) {
      debugPrint('[Ramadan] permission request failed: $e');
    }
    _ref.invalidate(notificationsPermittedProvider);
    await _settings.setLocation(lat: lat, lng: lng, label: label, plate: plate);
    await _settings.setEnabled(true);
    _ref
        .read(analyticsServiceProvider)
        .track(FunnelEvents.ramadanEnabled, props: {'location_source': source});
    await reschedule(copy);
    await _ref.read(waterControllerProvider).rescheduleReminders(waterCopy);
  }

  Future<void> disable(WaterReminderCopy waterCopy) async {
    await _settings.setEnabled(false);
    await _notifications.cancelRamadanNotifications();
    await _ref.read(waterControllerProvider).rescheduleReminders(waterCopy);
  }

  Future<void> setLocation({
    required double lat,
    required double lng,
    required String label,
    int? plate,
    required RamadanCopy copy,
    required WaterReminderCopy waterCopy,
  }) async {
    await _settings.setLocation(lat: lat, lng: lng, label: label, plate: plate);
    await reschedule(copy);
    await _ref.read(waterControllerProvider).rescheduleReminders(waterCopy);
  }

  Future<void> setSahurOffset(int min, RamadanCopy copy) async {
    await _settings.setSahurOffsetMin(min);
    await reschedule(copy);
  }

  Future<void> dismissOffer(int year) async {
    await _settings.dismissOffer(year);
    _ref.read(analyticsServiceProvider).track(FunnelEvents.ramadanOfferDismissed);
  }

  Future<void> setFasted(DateTime day, bool fasted) async {
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId == null) return;
    await _ref
        .read(fastingDaysLocalDataSourceProvider)
        .setFasted(userId, ramadanDayKey(day), fasted);
    _ref.invalidate(fastingDaysProvider);
    if (fasted) {
      _ref.read(analyticsServiceProvider).track(FunnelEvents.ramadanDayMarked);
    }
  }

  /// Cancels and re-arms every pending sahur/iftar notification (up to 7
  /// days out). Runs from the offer window on (`offerPeriod(now) != null`),
  /// so enabling before day 1 already arms day 1; only days inside
  /// `[firstDay, eidDay)` get notifications. Cancels everything and
  /// schedules nothing when the mode is off, no location is set, or the
  /// offer window has closed.
  Future<void> reschedule(RamadanCopy copy) async {
    try {
      final settings = _ref.read(ramadanSettingsProvider);
      final location = settings.location;
      final now = _now();
      final period = offerPeriod(now);
      if (!settings.enabled || location == null || period == null) {
        await _notifications.cancelRamadanNotifications();
        return;
      }
      final nextDays = [
        for (var i = 0; i < 7; i++)
          (
            DateTime(now.year, now.month, now.day + i),
            fastingTimes(
              DateTime(now.year, now.month, now.day + i),
              location.lat,
              location.lng,
            ),
          ),
      ];
      final items = ramadanNotificationTimes(
        now: now,
        nextDays: nextDays,
        sahurOffsetMin: settings.sahurOffsetMin,
        firstDay: period.firstDay,
        eidDay: period.eidDay,
      );
      await _notifications.rescheduleRamadanNotifications(
        items: items,
        sahurTitle: copy.sahurTitle,
        sahurBody: copy.sahurBody,
        iftarTitle: copy.iftarTitle,
        iftarBody: copy.iftarBody,
      );
    } catch (e) {
      debugPrint('[Ramadan] reschedule failed: $e');
    }
  }

  /// Call once per app launch and on every foreground resume. A warm
  /// resume never re-runs `build()` on cached providers —
  /// `fastingDaysProvider` reads `ramadanClockProvider()` once, the same
  /// staleness `waterTodayProvider` has (see `AppShellScreen`'s comment),
  /// and the OS notification permission may have changed in Settings — so
  /// both are force-refreshed here. Then turns the mode off once Ramadan's
  /// offer window has closed
  /// (so a forgotten switch doesn't keep steering water reminders at an
  /// iftar window that no longer exists), then re-arms notifications and
  /// water reminders for the day.
  Future<void> onResume(RamadanCopy copy, WaterReminderCopy waterCopy) async {
    _ref.invalidate(fastingDaysProvider);
    _ref.invalidate(notificationsPermittedProvider);

    final settings = _ref.read(ramadanSettingsProvider);
    if (settings.enabled && offerPeriod(_now()) == null) {
      await _settings.setEnabled(false);
    }
    await reschedule(copy);
    await _ref.read(waterControllerProvider).rescheduleReminders(waterCopy);
  }
}

final ramadanControllerProvider = Provider<RamadanController>(
  RamadanController.new,
);
