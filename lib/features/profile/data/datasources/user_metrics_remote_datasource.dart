import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/user_metrics_entity.dart';

/// Supabase-backed mirror of a signed-in user's body metrics
/// (`public.user_profiles`, columns added by the 2026-08-14 migration).
///
/// Guests never touch this — [upsert] is only called for
/// `AppSessionState.authenticated` users; local Drift stays the source of
/// truth for everyone else. Best-effort like the meal cloud sync's remote
/// data source: the caller decides retry/error policy, this class just
/// talks to Postgres.
///
/// Write-only by design: no read/fetch path exists here. There is no
/// cloud→local merge for metrics (unlike `MealSyncService.pullAndMerge`)
/// and none should be added without first deciding a "who wins" policy —
/// this class should stay exactly as wide as what actually calls it.
class UserMetricsRemoteDataSource {
  final SupabaseClient _client;

  static const _table = 'user_profiles';

  const UserMetricsRemoteDataSource(this._client);

  /// Upsert onto the caller's own `user_profiles` row (created by the
  /// `handle_new_user` trigger at signup, so this is effectively always an
  /// UPDATE via `onConflict: id`).
  ///
  /// Note: this does not write `updated_at` — `user_profiles` only sets it
  /// via `DEFAULT now()` at row creation, there's no UPDATE trigger. If a
  /// cloud-read/merge path is ever added, it would need to add
  /// `'updated_at': DateTime.now().toIso8601String()` here (or the table
  /// needs an UPDATE trigger) before any "last write wins" comparison
  /// could trust that column.
  Future<void> upsert(UserMetricsEntity m) async {
    await _client
        .from(_table)
        .upsert({
          'id': m.userId,
          'sex': m.sex.name,
          'birth_year': m.birthYear,
          'height_cm': m.heightCm,
          'weight_kg': m.weightKg,
          'target_weight_kg': m.targetWeightKg,
          'activity_level': m.activity.name,
        }, onConflict: 'id');
  }
}
