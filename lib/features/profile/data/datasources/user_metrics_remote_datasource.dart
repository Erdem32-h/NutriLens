import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/calorie_target_calculator.dart';
import '../../domain/entities/user_metrics_entity.dart';

/// Supabase-backed mirror of a signed-in user's body metrics
/// (`public.user_profiles`, columns added by the 2026-08-14 migration).
///
/// Guests never touch this — [upsert] is only called for
/// `AppSessionState.authenticated` users; local Drift stays the source of
/// truth for everyone else. Best-effort like the meal cloud sync's remote
/// data source: the caller decides retry/error policy, this class just
/// talks to Postgres.
class UserMetricsRemoteDataSource {
  final SupabaseClient _client;

  static const _table = 'user_profiles';

  const UserMetricsRemoteDataSource(this._client);

  /// Upsert onto the caller's own `user_profiles` row (created by the
  /// `handle_new_user` trigger at signup, so this is effectively always an
  /// UPDATE via `onConflict: id`).
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

  /// Reads the caller's own metrics row, or null if none of the metrics
  /// columns have been filled in yet (a fresh `user_profiles` row from the
  /// signup trigger has them all null).
  Future<UserMetricsEntity?> fetch(String userId) async {
    final row = await _client
        .from(_table)
        .select('sex, birth_year, height_cm, weight_kg, target_weight_kg, activity_level, updated_at')
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    final sex = row['sex'] as String?;
    final birthYear = row['birth_year'] as int?;
    final heightCm = row['height_cm'] as int?;
    final weightKg = (row['weight_kg'] as num?)?.toDouble();
    final activityLevel = row['activity_level'] as String?;
    if (sex == null ||
        birthYear == null ||
        heightCm == null ||
        weightKg == null ||
        activityLevel == null) {
      return null;
    }
    return UserMetricsEntity(
      userId: userId,
      sex: BiologicalSex.values.firstWhere(
        (e) => e.name == sex,
        orElse: () => BiologicalSex.unspecified,
      ),
      birthYear: birthYear,
      heightCm: heightCm,
      weightKg: weightKg,
      targetWeightKg: (row['target_weight_kg'] as num?)?.toDouble(),
      activity: ActivityLevel.values.firstWhere(
        (e) => e.name == activityLevel,
        orElse: () => ActivityLevel.sedentary,
      ),
      updatedAt:
          DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
