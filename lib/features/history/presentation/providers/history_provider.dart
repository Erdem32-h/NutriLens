import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../product/presentation/providers/product_provider.dart';
import '../../data/datasources/scan_history_local_datasource.dart';

// --- Data Source ---

final scanHistoryLocalDataSourceProvider =
    Provider<ScanHistoryLocalDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ScanHistoryLocalDataSourceImpl(db);
});

// --- History List (Supabase-primary, local fallback) ---

/// Fetches scan history from Supabase first, falls back to local Drift cache.
/// Enriches Supabase results with product info from local Drift cache.
final scanHistoryProvider =
    FutureProvider<List<ScanHistoryWithProduct>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  // Try Supabase first for cross-device sync
  try {
    final response = await Supabase.instance.client
        .from('scan_history')
        .select()
        .eq('user_id', userId)
        .order('scanned_at', ascending: false)
        .limit(50);

    final rows = response as List<dynamic>;
    if (rows.isNotEmpty) {
      final productLocal = ref.watch(productLocalDataSourceProvider);
      final results = await Future.wait(rows.map((row) async {
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
        );
      }));
      return results;
    }
  } catch (_) {
    // Supabase failed — fall back to local
  }

  // Fallback: local Drift cache (already joins with food_products)
  final ds = ref.watch(scanHistoryLocalDataSourceProvider);
  return ds.getHistory(userId: userId);
});

// --- Add Scan ---

/// Saves a barcode scan to history (both local + Supabase).
Future<void> addScanToHistory(
  WidgetRef ref, {
  required String barcode,
  double? hpScore,
}) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  try {
    // Write to local Drift
    final ds = ref.read(scanHistoryLocalDataSourceProvider);
    await ds.addScan(
      userId: userId,
      barcode: barcode,
      hpScore: hpScore,
    );
    ref.invalidate(scanHistoryProvider);

    // Sync to Supabase with hp_score
    await Supabase.instance.client.from('scan_history').upsert(
      {
        'user_id': userId,
        'barcode': barcode,
        'scanned_at': DateTime.now().toIso8601String(),
        'hp_score_at_scan': hpScore,
      },
      onConflict: 'user_id,barcode',
    );
  } catch (_) {
    // History save failure is non-critical
  }
}

// --- Delete Scan ---

Future<void> deleteScanFromHistory(WidgetRef ref, String id) async {
  // Delete from Supabase first
  try {
    await Supabase.instance.client.from('scan_history').delete().eq('id', id);
  } catch (_) {
    // Non-critical
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
final favoritesProvider =
    FutureProvider<List<ScanHistoryWithProduct>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('favorites')
        .select()
        .eq('user_id', userId)
        .order('added_at', ascending: false);

    final rows = response as List<dynamic>;
    final productLocal = ref.watch(productLocalDataSourceProvider);
    final results = await Future.wait(rows.map((row) async {
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
    }));
    return results;
  } catch (_) {
    return [];
  }
});

/// Check if a barcode is in favorites.
final isFavoriteProvider =
    FutureProvider.family<bool, String>((ref, barcode) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
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
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;

  try {
    // Remove from blacklist first (mutual exclusion)
    await Supabase.instance.client
        .from('blacklist')
        .delete()
        .eq('user_id', userId)
        .eq('barcode', barcode);

    await Supabase.instance.client.from('favorites').upsert(
      {
        'user_id': userId,
        'barcode': barcode,
        'added_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,barcode',
    );
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
  final userId = Supabase.instance.client.auth.currentUser?.id;
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
final blacklistProvider =
    FutureProvider<List<ScanHistoryWithProduct>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  try {
    final response = await Supabase.instance.client
        .from('blacklist')
        .select()
        .eq('user_id', userId)
        .order('added_at', ascending: false);

    final rows = response as List<dynamic>;
    final productLocal = ref.watch(productLocalDataSourceProvider);
    final results = await Future.wait(rows.map((row) async {
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
    }));
    return results;
  } catch (_) {
    return [];
  }
});

/// Check if a barcode is in the blacklist.
final isBlacklistedProvider =
    FutureProvider.family<bool, String>((ref, barcode) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
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
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;

  try {
    // Remove from favorites first (mutual exclusion)
    await Supabase.instance.client
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('barcode', barcode);

    await Supabase.instance.client.from('blacklist').upsert(
      {
        'user_id': userId,
        'barcode': barcode,
        'reason': ?reason,
        'added_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,barcode',
    );
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
Future<bool> removeFromBlacklist(WidgetRef ref, {required String id, required String barcode}) async {
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
  final userId = Supabase.instance.client.auth.currentUser?.id;
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
