import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_id_service.dart';

/// Outcome of a server-side guest scan check.
class GuestScanResult {
  final bool allowed;
  final int remaining;

  const GuestScanResult({required this.allowed, required this.remaining});
}

/// Server-authoritative guest (un-registered) scan budget, keyed by a hashed
/// device id so clearing the app's cache/data no longer resets the count.
///
/// Guests have no auth user, so these call anon-executable SECURITY DEFINER
/// RPCs (the `guest_devices` table itself is not reachable via the Data API).
/// Every method returns `null` on failure so the caller can fall back to the
/// local [GuestScanCounter] (offline-lenient policy).
class GuestScanLimitService {
  GuestScanLimitService(this._client, this._deviceId);

  final SupabaseClient _client;
  final DeviceIdService _deviceId;

  /// Atomically consumes one scan. Returns `null` when the server can't be
  /// reached (caller falls back to the local counter).
  Future<GuestScanResult?> checkAndIncrement() async {
    try {
      final hash = await _deviceId.deviceHash();
      final resp = await _client.rpc(
        'check_and_increment_guest_scan',
        params: {'p_device_hash': hash},
      );
      final m = resp as Map<String, dynamic>;
      return GuestScanResult(
        allowed: m['allowed'] as bool? ?? false,
        remaining: m['remaining'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('[GuestScanLimit] check RPC error: $e');
      return null;
    }
  }

  /// Read-only remaining budget for the scanner badge. `null` on error.
  Future<int?> peekRemaining() async {
    try {
      final hash = await _deviceId.deviceHash();
      final resp = await _client.rpc(
        'peek_guest_scan',
        params: {'p_device_hash': hash},
      );
      return (resp as Map<String, dynamic>)['remaining'] as int?;
    } catch (e) {
      debugPrint('[GuestScanLimit] peek RPC error: $e');
      return null;
    }
  }
}
