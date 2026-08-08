import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/failure_reason.dart';

class ScanCheckResult {
  final bool allowed;
  final int remaining;
  final bool isPremium;
  final String? reason;

  /// Machine code for the underlying cause when [reason] is a coarse bucket.
  /// Telemetry only — never rendered.
  final String? detail;

  const ScanCheckResult({
    required this.allowed,
    required this.remaining,
    required this.isPremium,
    this.reason,
    this.detail,
  });

  factory ScanCheckResult.fromJson(Map<String, dynamic> json) {
    return ScanCheckResult(
      allowed: json['allowed'] as bool? ?? false,
      remaining: json['remaining'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }

  /// Premium users with a known local entitlement (RevenueCat cache).
  static const unlimited = ScanCheckResult(
    allowed: true,
    remaining: -1,
    isPremium: true,
  );

  /// Server unreachable — fail closed so scan limits cannot be bypassed offline.
  ///
  /// [detail] carries the machine code for *why* (see `authFailureReason`) so
  /// the caller can report it without changing the UI branch, which keys off
  /// [reason]. It is never shown to the user.
  factory ScanCheckResult.networkBlocked(String detail) => ScanCheckResult(
    allowed: false,
    remaining: 0,
    isPremium: false,
    reason: 'network_error',
    detail: detail,
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
      return await _callCheck(userId);
    } catch (e, st) {
      // An access token that rolled over while the device was asleep comes
      // back as a 401/PGRST301 from PostgREST — not a transport failure. The
      // old blanket catch reported both as `network_error`, so the user got
      // "check your internet connection" and a blocked scan on a perfectly
      // good network. Refresh once and retry, the way GeminiAiService._invoke
      // already does for the proxy.
      if (_isAuthError(e)) {
        debugPrint('[ScanLimit] auth error — refreshing session and retrying');
        try {
          await _client.auth.refreshSession();
          return await _callCheck(userId);
        } catch (retryError, retrySt) {
          return _blocked(retryError, retrySt, 'check_retry');
        }
      }
      return _blocked(e, st, 'check');
    }
  }

  Future<ScanCheckResult> _callCheck(String userId) async {
    final response = await _client.rpc(
      'check_and_increment_scan',
      params: {'p_user_id': userId},
    );
    return ScanCheckResult.fromJson(response as Map<String, dynamic>);
  }

  /// PostgREST surfaces an expired/invalid JWT as a 401 (`PGRST301`), and the
  /// client itself throws [AuthException] when it cannot produce a token at
  /// all. Both are recoverable by a refresh; nothing else here is.
  static bool _isAuthError(Object error) {
    if (error is AuthException) return true;
    if (error is PostgrestException) {
      final code = error.code;
      if (code == '401' || code == 'PGRST301' || code == 'PGRST302') {
        return true;
      }
      return error.message.toLowerCase().contains('jwt');
    }
    return false;
  }

  /// Fail closed, but leave a trace. This path used to be completely silent —
  /// no Sentry, no analytics — which is why a scan-blocking error could run
  /// in production indefinitely without showing up anywhere.
  ScanCheckResult _blocked(Object error, StackTrace st, String op) {
    final reason = authFailureReason(error);
    debugPrint('[ScanLimit] $op failed ($reason): $error');
    unawaited(Sentry.captureException(error, stackTrace: st));
    return ScanCheckResult.networkBlocked(reason);
  }

  /// Read-only remaining budget for scanner badges (does not consume a scan).
  Future<ScanCheckResult?> peekRemaining() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client.rpc(
        'peek_scan',
        params: {'p_user_id': userId},
      );
      final json = response as Map<String, dynamic>;
      return ScanCheckResult(
        allowed: (json['remaining'] as int? ?? 0) > 0 ||
            (json['is_premium'] as bool? ?? false),
        remaining: json['remaining'] as int? ?? 0,
        isPremium: json['is_premium'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('[ScanLimit] peek RPC error: $e');
      return null;
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
