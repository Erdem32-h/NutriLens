import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../config/drift/app_database.dart';

/// Pushes today's meal summary to the OS-level home-screen widget on
/// both Android (AppWidget) and iOS (WidgetKit).
///
/// The widget design is a single "today snapshot + Tara button" card:
///   • Big number   → kcal eaten today
///   • Subtitle     → "N öğün" (count of meals captured today)
///   • CTA          → tap deep-links to `nutrilens://scanner`
///
/// Update triggers:
///   1. App startup (bootstrap) — initial population
///   2. After a meal is saved or deleted
///   3. After a barcode scan is added to history (so user feels the
///      app is "live" even before reopening it)
///   4. OS scheduler — Android refresh interval is configured in the
///      provider XML (every ~2h); iOS uses timeline policy.
class HomeWidgetService {
  // Must match the native widget's group/provider name.
  static const String _androidProviderName = 'NutriLensHomeWidgetProvider';
  // iOS App Group + widget kind. Keep in sync with Swift code.
  static const String _appGroupId = 'group.app.nutrilens.ios';
  static const String _iosWidgetName = 'NutriLensHomeWidget';

  // Keys written to shared storage; native code reads the same keys.
  static const _keyKcal = 'today_kcal';
  static const _keyMealCount = 'today_meal_count';
  static const _keyLastUpdate = 'last_update_iso';

  final AppDatabase _db;

  const HomeWidgetService(this._db);

  /// One-time bootstrap. The app group MUST be set before the first
  /// `saveWidgetData` call or iOS writes go to the default sandbox and
  /// the widget never sees them.
  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      // Older OS / not-installed widget — non-fatal.
      debugPrint('[HomeWidget] setAppGroupId failed: $e');
    }
  }

  /// Recompute today's snapshot from Drift and push it to the widget.
  /// Safe to call from anywhere; failures are logged and swallowed —
  /// the widget is a nice-to-have, never break the host app for it.
  Future<void> refresh({String? userId}) async {
    try {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      // Sum kcal across all meals captured today. If a userId is
      // available we scope to that user; otherwise we sum across the
      // whole local table (fresh install / signed-out edge cases just
      // produce a 0 — no privacy leak because Drift is per-device).
      final query = _db.select(_db.mealEntries)
        ..where(
          (t) =>
              t.capturedAt.isBiggerOrEqualValue(dayStart) &
              t.capturedAt.isSmallerThanValue(dayEnd),
        );
      if (userId != null) {
        query.where((t) => t.userId.equals(userId));
      }
      final rows = await query.get();

      var kcal = 0.0;
      for (final r in rows) {
        kcal += r.calories;
      }
      final count = rows.length;

      await Future.wait<void>([
        HomeWidget.saveWidgetData<int>(_keyKcal, kcal.round()),
        HomeWidget.saveWidgetData<int>(_keyMealCount, count),
        HomeWidget.saveWidgetData<String>(
          _keyLastUpdate,
          now.toIso8601String(),
        ),
      ]);

      await HomeWidget.updateWidget(
        name: _androidProviderName,
        androidName: _androidProviderName,
        iOSName: _iosWidgetName,
      );

      debugPrint('[HomeWidget] refreshed → ${kcal.round()} kcal · $count öğün');
    } catch (e) {
      debugPrint('[HomeWidget] refresh failed: $e');
    }
  }
}
