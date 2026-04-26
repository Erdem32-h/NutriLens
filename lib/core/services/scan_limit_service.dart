import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ScanCheckResult {
  final bool allowed;
  final int remaining;
  final bool isPremium;

  const ScanCheckResult({
    required this.allowed,
    required this.remaining,
    required this.isPremium,
  });

  factory ScanCheckResult.fromJson(Map<String, dynamic> json) {
    return ScanCheckResult(
      allowed: json['allowed'] as bool? ?? false,
      remaining: json['remaining'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }

  /// Premium users or fallback when server unreachable
  static const unlimited = ScanCheckResult(
    allowed: true,
    remaining: -1,
    isPremium: true,
  );
}

class BonusScanResult {
  final bool granted;
  final int bonusRemaining;
  final String? reason;

  const BonusScanResult({
    required this.granted,
    this.bonusRemaining = 0,
    this.reason,
  });

  factory BonusScanResult.fromJson(Map<String, dynamic> json) {
    return BonusScanResult(
      granted: json['granted'] as bool? ?? false,
      bonusRemaining: json['bonus_remaining'] as int? ?? 0,
      reason: json['reason'] as String?,
    );
  }
}

class ScanLimitService {
  final SupabaseClient _client;

  const ScanLimitService(this._client);

  Future<ScanCheckResult> checkAndIncrement({bool localPremium = false}) async {
    if (localPremium) return ScanCheckResult.unlimited;

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const ScanCheckResult(
        allowed: false,
        remaining: 0,
        isPremium: false,
      );
    }

    try {
      final response = await _client.rpc(
        'check_and_increment_scan',
        params: {'p_user_id': userId},
      );
      return ScanCheckResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ScanLimit] RPC error: $e');
      // Graceful fallback: allow scan on network error
      return ScanCheckResult.unlimited;
    }
  }

  Future<BonusScanResult> grantBonusScan() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const BonusScanResult(granted: false, reason: 'not_authenticated');
    }

    try {
      final response = await _client.rpc(
        'grant_bonus_scan',
        params: {'p_user_id': userId},
      );
      return BonusScanResult.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ScanLimit] Bonus RPC error: $e');
      return const BonusScanResult(granted: false, reason: 'network_error');
    }
  }
}
