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
      return rows.map((row) {
        final map = row as Map<String, dynamic>;
        return ScanHistoryWithProduct(
          id: map['id'] as String,
          barcode: map['barcode'] as String,
          scannedAt: DateTime.parse(map['scanned_at'] as String),
          hpScoreAtScan: map['hp_score_at_scan'] != null
              ? (map['hp_score_at_scan'] as num).toDouble()
              : null,
          productName: map['product_name'] as String?,
          brands: map['brand'] as String?,
          imageUrl: map['image_url'] as String?,
        );
      }).toList();
    }
  } catch (_) {
    // Supabase failed — fall back to local
  }

  // Fallback: local Drift cache
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

/// Fetches favorites from Supabase.
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
    return rows.map((row) {
      final map = row as Map<String, dynamic>;
      return ScanHistoryWithProduct(
        id: map['id'] as String,
        barcode: map['barcode'] as String,
        scannedAt: DateTime.parse(map['added_at'] as String),
        hpScoreAtScan: map['hp_score_at_scan'] != null
            ? (map['hp_score_at_scan'] as num).toDouble()
            : null,
        productName: map['product_name'] as String?,
        brands: map['brand'] as String?,
        imageUrl: map['image_url'] as String?,
      );
    }).toList();
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
Future<bool> addToFavorites(WidgetRef ref, {required String barcode}) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return false;

  try {
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
