import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/score_constants.dart';
import '../../../../core/session/app_session.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../meals/presentation/providers/meal_provider.dart';
import '../../../product/presentation/providers/product_provider.dart';
import '../../data/datasources/scan_history_local_datasource.dart';

// ── Background product enrichment ─────────────────────────────────────────
//
// Two distinct cases trigger a background re-fetch:
//
// 1. **Missing cache** — after a fresh install the local Drift
//    `food_products` table is empty, so history/favorites/blacklist
//    rows show just the barcode. We re-resolve via the repo chain
//    (community → OFF → barcode lookup), which side-effects the local
//    cache (`ProductRepositoryImpl._resolveFromSources`).
//
// 2. **Stale HP-Score algorithm version** — when we bump
//    `ScoreConstants.hpScoreAlgorithmVersion` (e.g. v2 → v3 sweet-treat
//    penalty), every locally-cached row is now scored with an outdated
//    formula. We treat those as needing re-resolve too. The Supabase
//    `community_products` trigger always emits the current-version
//    score, so a single re-fetch brings the row up to date.
//
// Once at least one row is refreshed the provider is invalidated so the
// UI re-renders with the new data. Failure de-dupe (`_enrichmentFailed`)
// is session-scoped — a barcode that doesn't exist in any source is
// only retried after an app restart.

final _enrichmentInFlight = <String>{};
final _enrichmentFailed = <String>{};
const int _enrichmentConcurrency = 4;

Future<void> _enrichMissingProducts(
  Ref ref,
  List<ScanHistoryWithProduct> items,
) async {
  final candidates = <String>[];
  for (final item in items) {
    final barcode = item.barcode;
    final isMissing = item.productName == null || item.productName!.isEmpty;
    final isVersionStale =
        item.hpScoreVersion != null &&
        item.hpScoreVersion! < ScoreConstants.hpScoreAlgorithmVersion;
    if (!isMissing && !isVersionStale) continue;
    if (_enrichmentFailed.contains(barcode)) continue;
    if (_enrichmentInFlight.contains(barcode)) continue;
    candidates.add(barcode);
  }
  if (candidates.isEmpty) return;

  // Mark all up-front so a second build of the same provider doesn't
  // double-fire while the first batch is still in flight.
  _enrichmentInFlight.addAll(candidates);

  final useCase = ref.read(getProductUseCaseProvider);
  var anyResolved = false;

  // Concurrency-limited fan-out — OFF has loose rate limits but we don't
  // want to fire 50 parallel HTTPS calls on app launch either.
  final iter = candidates.iterator;
  final workers = List.generate(
    _enrichmentConcurrency,
    (_) => () async {
      while (true) {
        String barcode;
        if (!iter.moveNext()) return;
        barcode = iter.current;
        try {
          final res = await useCase(barcode);
          res.fold(
            (_) => _enrichmentFailed.add(barcode),
            (_) => anyResolved = true,
          );
        } catch (e) {
          debugPrint('[history-enrich] $barcode failed: $e');
          _enrichmentFailed.add(barcode);
        } finally {
          _enrichmentInFlight.remove(barcode);
        }
      }
    }(),
  );
  await Future.wait(workers);

  if (anyResolved) {
    // Ask the originating provider to rebuild so the now-cached entries
    // get joined in. Wrapped in a try because the provider may have been
    // auto-disposed while we were fetching.
    try {
      ref.invalidateSelf();
    } catch (_) {
      /* listener gone — no-op */
    }
  }
}

// --- Data Source ---

final scanHistoryLocalDataSourceProvider = Provider<ScanHistoryLocalDataSource>(
  (ref) {
    final db = ref.watch(appDatabaseProvider);
    return ScanHistoryLocalDataSourceImpl(db);
  },
);

// --- History List (Supabase + local Drift, merged) ---

/// Fetches scan history for the current user.
///
/// Authenticated: merges the Supabase list (cross-device sync) with the
/// local Drift cache so scans that haven't synced yet — offline scans, or a
/// transient server error — still appear instead of being masked by the
/// remote list. Remote rows win on conflict (the (user, barcode) unique
/// key); local-only rows are appended. Rows are enriched with product info
/// from the local product cache.
///
/// Guest mode: skip Supabase entirely (the sentinel id is meaningless
/// server-side), read straight from local Drift where guest scans live.
final scanHistoryProvider = FutureProvider<List<ScanHistoryWithProduct>>((
  ref,
) async {
  final userId = ref.watch(effectiveUserIdProvider);
  if (userId == null) return [];
  final isGuest = ref.watch(isGuestProvider);

  // Local Drift is always read: the source for guests, and the fallback /
  // unsynced-scan source for authenticated users.
  final ds = ref.watch(scanHistoryLocalDataSourceProvider);
  final localResults = await ds.getHistory(userId: userId);

  if (isGuest) {
    unawaited(_enrichMissingProducts(ref, localResults));
    return localResults;
  }

  // Authenticated: pull the remote list for cross-device sync, then merge.
  List<ScanHistoryWithProduct> remoteResults;
  try {
    final response = await Supabase.instance.client
        .from('scan_history')
        .select()
        .eq('user_id', userId)
        .order('scanned_at', ascending: false)
        .limit(50);

    final productLocal = ref.watch(productLocalDataSourceProvider);
    remoteResults = await Future.wait(
      (response as List<dynamic>).map((row) async {
        final map = row as Map<String, dynamic>;
        final barcode = map['barcode'] as String;
        // Enrich with local product cache for display info
        final product = await productLocal.getProduct(barcode);
        return ScanHistoryWithProduct(
          id: map['id'] as String,
          barcode: barcode,
          scannedAt: DateTime.parse(map['scanned_at'] as String),
          hpScoreAtScan: map['hp_score_at_scan'] != null
              ? (map['hp_score_at_scan'] as num).toDouble()
              : null,
          productName: product?.productName,
          brands: product?.brands,
          imageUrl: product?.imageUrl,
          ingredientsText: product?.ingredientsText,
          currentHpScore: product?.calculatedHpScore,
          hpScoreVersion: product?.hpScoreVersion,
        );
      }),
    );
  } catch (_) {
    // Supabase unreachable — show the local cache alone.
    unawaited(_enrichMissingProducts(ref, localResults));
    return localResults;
  }

  // Merge by barcode. Remote rows win (synced source of truth + richer
  // enrichment); local-only rows (not yet synced) are appended so they
  // stay visible instead of being masked by a non-empty remote list.
  final byBarcode = <String, ScanHistoryWithProduct>{
    for (final item in remoteResults) item.barcode: item,
  };
  for (final item in localResults) {
    byBarcode.putIfAbsent(item.barcode, () => item);
  }
  final results = byBarcode.values.toList()
    ..sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  final limited = results.take(50).toList();

  unawaited(_enrichMissingProducts(ref, limited));
  return limited;
});

// --- Add Scan ---

/// Saves a barcode scan to history. Always writes to local Drift; only
/// pushes to Supabase when the user is authenticated (guest scans stay
/// on-device until the user signs up — see migration flow).
Future<void> addScanToHistory(
  WidgetRef ref, {
  required String barcode,
  double? hpScore,
}) async {
  final userId = ref.read(effectiveUserIdProvider);
  if (userId == null) return;
  final isGuest = ref.read(isGuestProvider);

  try {
    // Write to local Drift
    final ds = ref.read(scanHistoryLocalDataSourceProvider);
    await ds.addScan(userId: userId, barcode: barcode, hpScore: hpScore);
    ref.invalidate(scanHistoryProvider);
    // Push the new "last scan" / meal-count snapshot to the home widget.
    unawaited(ref.read(homeWidgetServiceProvider).refresh(userId: userId));

    if (isGuest) return;

    // Sync to Supabase with hp_score
    await Supabase.instance.client.from('scan_history').upsert({
      'user_id': userId,
      'barcode': barcode,
      'scanned_at': DateTime.now().toIso8601String(),
      'hp_score_at_scan': hpScore,
    }, onConflict: 'user_id,barcode');
  } catch (e, st) {
    // Non-critical to the scan flow (the local Drift write above already
    // succeeded), but never swallow silently — a silent catch here hid a
    // numeric-overflow sync failure (score 100.0 vs a numeric(4,2) column)
    // for a long time. Log + report so the next one is visible.
    debugPrint('[addScanToHistory] history sync failed: $e');
    unawaited(Sentry.captureException(e, stackTrace: st));
  }
}

// --- Delete Scan ---

Future<void> deleteScanFromHistory(WidgetRef ref, String id) async {
  final isGuest = ref.read(isGuestProvider);

  // Delete from Supabase first (skip for guests — they have no remote row)
  if (!isGuest) {
    try {
      await Supabase.instance.client.from('scan_history').delete().eq('id', id);
    } catch (_) {
      // Non-critical
    }
  }

  // Delete from local
  try {
    final ds = ref.read(scanHistoryLocalDataSourceProvider);
    await ds.deleteScan(id);
  } catch (_) {
    // Non-critical
  }

  ref.invalidate(scanHistoryProvider);
}

// --- Favorites ---

/// Fetches favorites from Supabase, enriched with local product cache.
final favoritesProvider = FutureProvider<List<ScanHistoryWithProduct>>((
  ref,
) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('favorites')
        .select()
        .eq('user_id', userId)
        .order('added_at', ascending: false);

    final rows = response as List<dynamic>;
    final productLocal = ref.watch(productLocalDataSourceProvider);
    final results = await Future.wait(
      rows.map((row) async {
        final map = row as Map<String, dynamic>;
        final barcode = map['barcode'] as String;
        final product = await productLocal.getProduct(barcode);
        return ScanHistoryWithProduct(
          id: map['id'] as String,
          barcode: barcode,
          scannedAt: DateTime.parse(map['added_at'] as String),
          hpScoreAtScan: null,
          productName: product?.productName,
          brands: product?.brands,
          imageUrl: product?.imageUrl,
          ingredientsText: product?.ingredientsText,
          currentHpScore: product?.calculatedHpScore,
        );
      }),
    );
    unawaited(_enrichMissingProducts(ref, results));
    return results;
  } catch (_) {
    return [];
  }
});

/// Check if a barcode is in favorites.
final isFavoriteProvider = FutureProvider.family<bool, String>((
  ref,
  barcode,
) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return false;

  try {
    final response = await Supabase.instance.client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('barcode', barcode)
        .maybeSingle();
    return response != null;
  } catch (_) {
    return false;
  }
});

/// Add a barcode to favorites.
/// Mutual exclusion: automatically removes from blacklist if present.
Future<bool> addToFavorites(WidgetRef ref, {required String barcode}) async {
  final userId = ref.read(currentUserProvider)?.id;
  if (userId == null) return false;

  try {
    // Remove from blacklist first (mutual exclusion)
    await Supabase.instance.client
        .from('blacklist')
        .delete()
        .eq('user_id', userId)
        .eq('barcode', barcode);

    await Supabase.instance.client.from('favorites').upsert({
      'user_id': userId,
      'barcode': barcode,
      'added_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,barcode');
    ref.invalidate(favoritesProvider);
    ref.invalidate(isFavoriteProvider(barcode));
    ref.invalidate(blacklistProvider);
    ref.invalidate(isBlacklistedProvider(barcode));
    return true;
  } catch (_) {
    return false;
  }
}

/// Remove a favorite by its id.
Future<bool> removeFromFavorites(WidgetRef ref, {required String id}) async {
  try {
    await Supabase.instance.client.from('favorites').delete().eq('id', id);
    ref.invalidate(favoritesProvider);
    return true;
  } catch (_) {
    return false;
  }
}

/// Remove a favorite by barcode (for use when only barcode is available).
Future<bool> removeFavoriteByBarcode(
  WidgetRef ref, {
  required String barcode,
}) async {
  final userId = ref.read(currentUserProvider)?.id;
  if (userId == null) return false;

  try {
    await Supabase.instance.client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('barcode', barcode);
    ref.invalidate(favoritesProvider);
    ref.invalidate(isFavoriteProvider(barcode));
    return true;
  } catch (_) {
    return false;
  }
}

// --- Blacklist ---

/// Fetches blacklisted products from Supabase, enriched with local product cache.
final blacklistProvider = FutureProvider<List<ScanHistoryWithProduct>>((
  ref,
) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('blacklist')
        .select()
        .eq('user_id', userId)
        .order('added_at', ascending: false);

    final rows = response as List<dynamic>;
    final productLocal = ref.watch(productLocalDataSourceProvider);
    final results = await Future.wait(
      rows.map((row) async {
        final map = row as Map<String, dynamic>;
        final barcode = map['barcode'] as String;
        final product = await productLocal.getProduct(barcode);
        return ScanHistoryWithProduct(
          id: map['id'] as String,
          barcode: barcode,
          scannedAt: DateTime.parse(map['added_at'] as String),
          hpScoreAtScan: null,
          productName: product?.productName,
          brands: product?.brands,
          imageUrl: product?.imageUrl,
          ingredientsText: product?.ingredientsText,
          currentHpScore: product?.calculatedHpScore,
        );
      }),
    );
    unawaited(_enrichMissingProducts(ref, results));
    return results;
  } catch (_) {
    return [];
  }
});

/// Check if a barcode is in the blacklist.
final isBlacklistedProvider = FutureProvider.family<bool, String>((
  ref,
  barcode,
) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return false;

  try {
    final response = await Supabase.instance.client
        .from('blacklist')
        .select('id')
        .eq('user_id', userId)
        .eq('barcode', barcode)
        .maybeSingle();
    return response != null;
  } catch (_) {
    return false;
  }
});

/// Add a barcode to the blacklist.
/// Mutual exclusion: automatically removes from favorites if present.
Future<bool> addToBlacklist(
  WidgetRef ref, {
  required String barcode,
  String? reason,
}) async {
  final userId = ref.read(currentUserProvider)?.id;
  if (userId == null) return false;

  try {
    // Remove from favorites first (mutual exclusion)
    await Supabase.instance.client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('barcode', barcode);

    await Supabase.instance.client.from('blacklist').upsert({
      'user_id': userId,
      'barcode': barcode,
      'reason': ?reason,
      'added_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,barcode');
    ref.invalidate(blacklistProvider);
    ref.invalidate(isBlacklistedProvider(barcode));
    ref.invalidate(favoritesProvider);
    ref.invalidate(isFavoriteProvider(barcode));
    return true;
  } catch (_) {
    return false;
  }
}

/// Remove a blacklist entry by its id.
Future<bool> removeFromBlacklist(
  WidgetRef ref, {
  required String id,
  required String barcode,
}) async {
  try {
    await Supabase.instance.client.from('blacklist').delete().eq('id', id);
    ref.invalidate(blacklistProvider);
    ref.invalidate(isBlacklistedProvider(barcode));
    return true;
  } catch (_) {
    return false;
  }
}

/// Remove a blacklist entry by barcode (for use when only barcode is available).
Future<bool> removeBlacklistByBarcode(
  WidgetRef ref, {
  required String barcode,
}) async {
  final userId = ref.read(currentUserProvider)?.id;
  if (userId == null) return false;

  try {
    await Supabase.instance.client
        .from('blacklist')
        .delete()
        .eq('user_id', userId)
        .eq('barcode', barcode);
    ref.invalidate(blacklistProvider);
    ref.invalidate(isBlacklistedProvider(barcode));
    return true;
  } catch (_) {
    return false;
  }
}
