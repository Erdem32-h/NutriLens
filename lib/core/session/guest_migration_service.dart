import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/history/data/datasources/scan_history_local_datasource.dart';
import '../../features/history/presentation/providers/history_provider.dart';
import '../../features/meals/data/datasources/meal_local_datasource.dart';
import '../../features/meals/presentation/providers/meal_provider.dart';
import '../services/guest_scan_counter.dart';
import 'app_session.dart';

/// Snapshot of what would be moved during a guest→register migration.
/// Shown to the user in the post-register prompt so they can decide
/// whether to upload their on-device data to their fresh account.
class GuestDataSummary {
  final int scanCount;
  final int mealCount;

  const GuestDataSummary({required this.scanCount, required this.mealCount});

  bool get isEmpty => scanCount == 0 && mealCount == 0;
}

class GuestMigrationService {
  final ScanHistoryLocalDataSource _scanDs;
  final MealLocalDataSource _mealDs;
  final SupabaseClient _supabase;
  final GuestScanCounter _counter;

  GuestMigrationService({
    required ScanHistoryLocalDataSource scanDs,
    required MealLocalDataSource mealDs,
    required SupabaseClient supabase,
    required GuestScanCounter counter,
  })  : _scanDs = scanDs,
        _mealDs = mealDs,
        _supabase = supabase,
        _counter = counter;

  Future<GuestDataSummary> inspectPending() async {
    final scans = await _scanDs.countByUser(kGuestUserId);
    final meals = await _mealDs.countByUser(kGuestUserId);
    return GuestDataSummary(scanCount: scans, mealCount: meals);
  }

  /// Performs the migration:
  ///   1. Re-key local Drift rows (scan_history, meal_entries) from
  ///      [kGuestUserId] to [newUserId] — instant, all-or-nothing per
  ///      table.
  ///   2. Bulk-upsert scan rows into Supabase so the new user sees
  ///      their guest history on other devices. Meals stay local-only
  ///      (matches the current "meals are device-local" design).
  ///   3. Resets the guest scan counter so the new authenticated user
  ///      starts with their server-side daily limit, not the consumed
  ///      guest budget.
  ///
  /// On Supabase failure the local reassignment still stands — the
  /// data is at least visible inside the app, and a future read-path
  /// retry can re-upload. Throwing here would leave the user wondering
  /// where their stuff went.
  Future<void> migrate({required String newUserId}) async {
    // 1. Local re-key (must succeed; otherwise the data is invisible)
    await _scanDs.reassignOwner(
      fromUserId: kGuestUserId,
      toUserId: newUserId,
    );
    await _mealDs.reassignOwner(
      fromUserId: kGuestUserId,
      toUserId: newUserId,
    );

    // 2. Cloud upload (best-effort — local data is already saved)
    try {
      final scans = await _scanDs.rawByUser(newUserId);
      if (scans.isNotEmpty) {
        final payload = scans
            .map((m) => {
                  'user_id': newUserId,
                  'barcode': m['barcode'],
                  'scanned_at': m['scanned_at'],
                  'hp_score_at_scan': m['hp_score_at_scan'],
                })
            .toList();
        await _supabase
            .from('scan_history')
            .upsert(payload, onConflict: 'user_id,barcode');
      }
    } catch (_) {
      // Non-fatal. Data is local; will sync on next read-write.
    }

    // 3. Reset guest counter so the new user gets fresh daily quota
    await _counter.reset();
  }

  /// Used when the user declines migration. Drops the guest-owned
  /// rows so they don't linger as orphaned data. We deliberately do
  /// NOT also touch the user's preferences (theme, locale, allergens)
  /// since those live in SharedPreferences and aren't tied to userId.
  Future<void> discard() async {
    final db = (_scanDs as ScanHistoryLocalDataSourceImpl);
    await db.clearHistory(kGuestUserId);
    // For meals we don't have a clearAll helper; reassign-to-discard
    // would leave stale rows. Easiest: read ids and delete them.
    final mealsToWipe = await _mealDs.getMeals(userId: kGuestUserId);
    for (final m in mealsToWipe) {
      await _mealDs.deleteMeal(m.id);
    }
    await _counter.reset();
  }
}

final guestMigrationServiceProvider = Provider<GuestMigrationService>((ref) {
  return GuestMigrationService(
    scanDs: ref.watch(scanHistoryLocalDataSourceProvider),
    mealDs: ref.watch(mealLocalDataSourceProvider),
    supabase: Supabase.instance.client,
    counter: ref.watch(guestScanCounterProvider.notifier),
  );
});
