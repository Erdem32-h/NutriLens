import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_event.dart';
import '../../../../core/analytics/analytics_provider.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../../ramadan/domain/ramadan_calendar.dart';
import '../../../ramadan/presentation/providers/ramadan_provider.dart';
import '../../data/fasting_sessions_local_datasource.dart';
import '../../data/fasting_settings_store.dart';
import '../../domain/fasting_protocol.dart';
import '../../domain/fasting_session.dart';
import '../fasting_actions.dart';

final fastingSettingsStoreProvider = Provider<FastingSettingsStore>(
  (ref) => FastingSettingsStore(ref.watch(sharedPreferencesProvider)),
);

final fastingSessionsLocalDataSourceProvider =
    Provider<FastingSessionsLocalDataSource>(
      (ref) => FastingSessionsLocalDataSourceImpl(ref.watch(appDatabaseProvider)),
    );

/// Test seam for "now".
final fastingClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

class FastingProtocolNotifier extends Notifier<FastingProtocol> {
  FastingSettingsStore get _store => ref.read(fastingSettingsStoreProvider);

  @override
  FastingProtocol build() => ref.watch(fastingSettingsStoreProvider).protocol;

  Future<void> setProtocol(FastingProtocol protocol) async {
    await _store.setProtocol(protocol);
    state = protocol;
  }
}

final fastingProtocolProvider =
    NotifierProvider<FastingProtocolNotifier, FastingProtocol>(
      FastingProtocolNotifier.new,
    );

/// The user's currently running fast, if any.
final activeFastProvider = FutureProvider<FastingSession?>((ref) async {
  final userId = ref.watch(effectiveUserIdProvider);
  if (userId == null) return null;
  return ref.watch(fastingSessionsLocalDataSourceProvider).active(userId);
});

/// Last 30 ended fasts, newest first. Read only when premium — the caller
/// decides that, this just fetches.
final fastingHistoryProvider = FutureProvider<List<FastingSession>>((
  ref,
) async {
  final userId = ref.watch(effectiveUserIdProvider);
  if (userId == null) return const [];
  return ref
      .watch(fastingSessionsLocalDataSourceProvider)
      .recent(userId, limit: 30);
});

/// While Ramadan mode is on and today falls inside the current Ramadan
/// period, IF entry points are hidden and starting a new fast is blocked —
/// an already-running fast keeps running (spec §"Ramadan").
final fastingBlockedByRamadanProvider = Provider<bool>((ref) {
  final settings = ref.watch(ramadanSettingsProvider);
  if (!settings.enabled) return false;
  final now = ref.watch(fastingClockProvider)();
  return currentRamadan(now) != null;
});

/// Single write path for fasting sessions/settings: datasource → invalidate
/// → notification → analytics. Notification failures never fail the write —
/// mirrors `RamadanController`.
class FastingController {
  final Ref _ref;

  FastingController(this._ref);

  FastingSessionsLocalDataSource get _sessions =>
      _ref.read(fastingSessionsLocalDataSourceProvider);
  NotificationService get _notifications =>
      _ref.read(notificationServiceProvider);
  DateTime _now() => _ref.read(fastingClockProvider)();

  /// Starts a new fast at the currently selected protocol. Returns `false`
  /// when blocked by Ramadan, when there is no user to own the row, or when
  /// the user already has an active fast (the datasource's atomic guard).
  Future<bool> start(FastingCopy copy) async {
    // Computed fresh rather than via `fastingBlockedByRamadanProvider`: that
    // provider caches its clock read until something invalidates it (see
    // `onResume`), so an app alive overnight into Ramadan day 1 — with no
    // resume in between — must not read a stale "not blocked" value here.
    final ramadan = _ref.read(ramadanSettingsProvider);
    if (ramadan.enabled && currentRamadan(_now()) != null) return false;
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId == null) return false;

    // Ask for notification permission (mirrors RamadanController.enable)
    // but start regardless of the answer.
    try {
      await _notifications.requestPermission();
    } catch (e) {
      debugPrint('[Fasting] permission request failed: $e');
    }

    final protocol = _ref.read(fastingProtocolProvider);
    final startedAt = _now();
    try {
      await _sessions.start(
        userId,
        startedAt: startedAt,
        targetMinutes: protocol.fastMinutes,
      );
    } on StateError {
      return false;
    }

    _ref.invalidate(activeFastProvider);
    _ref.invalidate(fastingHistoryProvider);

    try {
      await _notifications.scheduleFastingTarget(
        at: startedAt.add(Duration(minutes: protocol.fastMinutes)),
        title: copy.title,
        body: copy.body(protocol.fastMinutes ~/ 60),
      );
    } catch (e) {
      debugPrint('[Fasting] schedule failed: $e');
    }

    _ref
        .read(analyticsServiceProvider)
        .track(FunnelEvents.ifFastStarted, props: {'protocol': protocol.label});
    return true;
  }

  /// Ends the active fast, if any. No-op otherwise.
  Future<void> end({required String source}) async {
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId == null) return;
    final active = await _sessions.active(userId);
    if (active == null) return;

    final now = _now();
    await _sessions.end(active.id, now);

    try {
      await _notifications.cancelFastingTarget();
    } catch (e) {
      debugPrint('[Fasting] cancel failed: $e');
    }

    _ref.invalidate(activeFastProvider);
    _ref.invalidate(fastingHistoryProvider);

    final elapsed = now.difference(active.startedAt);
    final completed = elapsed >= Duration(minutes: active.targetMinutes);
    _ref.read(analyticsServiceProvider).track(
      FunnelEvents.ifFastEnded,
      props: {
        'completed': completed,
        'minutes': elapsed.inMinutes,
        'source': source,
      },
    );
  }

  /// Changes the selected protocol. No-op while a fast is active — the
  /// running fast's target was already locked in at start.
  Future<void> setProtocol(FastingProtocol protocol) async {
    final userId = _ref.read(effectiveUserIdProvider);
    if (userId != null && await _sessions.active(userId) != null) return;

    await _ref.read(fastingProtocolProvider.notifier).setProtocol(protocol);
    _ref
        .read(analyticsServiceProvider)
        .track(
          FunnelEvents.ifProtocolChanged,
          props: {'protocol': protocol.label},
        );
  }

  /// Call once per app launch and on every foreground resume. Force-
  /// refreshes the active fast (a warm resume never re-runs `build()` on
  /// cached providers — same staleness `fastingDaysProvider` has, see
  /// `AppShellScreen`), then re-arms the target notification if a fast is
  /// still running and its target hasn't passed yet — covers reboot /
  /// permission change. Never throws.
  Future<void> onResume(FastingCopy copy) async {
    _ref.invalidate(activeFastProvider);
    _ref.invalidate(fastingHistoryProvider);
    // Same staleness as above: a warm resume never re-runs `build()` on a
    // cached `Provider`, so the Ramadan-block flag (clock read at build
    // time) needs a forced refresh too — mirrors `fastingDaysProvider`.
    _ref.invalidate(fastingBlockedByRamadanProvider);

    final userId = _ref.read(effectiveUserIdProvider);
    if (userId == null) return;
    final active = await _sessions.active(userId);
    if (active == null) return;

    final target = active.startedAt.add(
      Duration(minutes: active.targetMinutes),
    );
    if (!target.isAfter(_now())) return;

    try {
      await _notifications.scheduleFastingTarget(
        at: target,
        title: copy.title,
        body: copy.body(active.targetMinutes ~/ 60),
      );
    } catch (e) {
      debugPrint('[Fasting] resume schedule failed: $e');
    }
  }
}

final fastingControllerProvider = Provider<FastingController>(
  FastingController.new,
);
