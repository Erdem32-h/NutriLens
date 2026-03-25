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

// --- History List ---

/// Fetches scan history for the current user.
final scanHistoryProvider =
    FutureProvider<List<ScanHistoryWithProduct>>((ref) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return [];

  final ds = ref.watch(scanHistoryLocalDataSourceProvider);
  return ds.getHistory(userId: userId);
});

// --- Add Scan ---

/// Saves a barcode scan to history. Call after product is loaded.
Future<void> addScanToHistory(
  WidgetRef ref, {
  required String barcode,
  double? hpScore,
}) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  try {
    final ds = ref.read(scanHistoryLocalDataSourceProvider);
    await ds.addScan(
      userId: userId,
      barcode: barcode,
      hpScore: hpScore,
    );
    // Invalidate so history screen refreshes
    ref.invalidate(scanHistoryProvider);
  } catch (_) {
    // History save failure is non-critical, don't break the flow
  }
}
