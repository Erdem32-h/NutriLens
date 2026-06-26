import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../product/data/models/nutriments_dto.dart';
import '../../domain/entities/meal_entry_entity.dart';

/// Supabase-backed meal store used only for **premium** users (cloud backup +
/// multi-device restore). Free users never touch this — their meals stay in
/// local Drift. All methods are best-effort; the sync service decides policy.
class MealRemoteDataSource {
  final SupabaseClient _client;

  static const _table = 'meal_entries';
  static const _bucket = 'meal-photos';

  const MealRemoteDataSource(this._client);

  /// Upsert a meal row. [photoUrl] is the Storage object path (`<uid>/<id>.jpg`)
  /// or null when there's no photo.
  Future<void> upsert(MealEntryEntity meal, {String? photoUrl}) async {
    await _client.from(_table).upsert({
      'id': meal.id,
      'user_id': meal.userId,
      'meal_name': meal.mealName,
      'brand': meal.brand,
      'meal_type': meal.mealType.name,
      'captured_at': meal.capturedAt.toUtc().toIso8601String(),
      'ingredients_text': meal.ingredientsText,
      'nutriments': NutrimentsDto.toMap(meal.nutriments),
      'calories': meal.calories,
      'hp_score': meal.hpScore,
      'confidence': meal.confidence,
      'ai_raw_json': meal.aiRawJson,
      'photo_url': photoUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<void> deleteRow(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  /// All cloud meals for [userId], newest first. Raw rows — the sync service
  /// maps them so it can read `updated_at`/`photo_url` during the merge.
  Future<List<Map<String, dynamic>>> fetchAll(String userId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('captured_at', ascending: false);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Upload a local thumbnail to `<userId>/<mealId>.jpg`. Returns the Storage
  /// path on success, null on failure (caller keeps the meal local_only).
  Future<String?> uploadPhoto({
    required String userId,
    required String mealId,
    required File file,
  }) async {
    try {
      final path = '$userId/$mealId.jpg';
      await _client.storage
          .from(_bucket)
          .upload(
            path,
            file,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> downloadPhoto(String path) async {
    try {
      return await _client.storage.from(_bucket).download(path);
    } catch (_) {
      return null;
    }
  }

  Future<void> deletePhoto(String path) async {
    try {
      await _client.storage.from(_bucket).remove([path]);
    } catch (_) {
      // Best-effort; an orphaned object is harmless.
    }
  }

  /// Map a cloud row to a domain entity. [thumbnailPath] is the local file the
  /// sync service downloaded (or the existing local path), may be null.
  static MealEntryEntity rowToEntity(
    Map<String, dynamic> row, {
    String? thumbnailPath,
  }) {
    return MealEntryEntity(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      photoThumbnailPath: thumbnailPath,
      mealName: (row['meal_name'] as String?) ?? '',
      brand: (row['brand'] as String?) ?? 'Ev yapımı',
      mealType: mealTypeFromString((row['meal_type'] as String?) ?? 'snack'),
      capturedAt:
          DateTime.tryParse(row['captured_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      ingredientsText: row['ingredients_text'] as String?,
      nutriments: NutrimentsDto.fromMap(
        (row['nutriments'] as Map?)?.cast<String, dynamic>(),
      ),
      calories: (row['calories'] as num?)?.toDouble() ?? 0,
      hpScore: (row['hp_score'] as num?)?.toDouble(),
      confidence: (row['confidence'] as num?)?.toDouble(),
      aiRawJson: row['ai_raw_json'] as String?,
      syncStatus: 'synced',
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toLocal(),
    );
  }

  /// Storage object path for a meal's photo.
  static String photoPath(String userId, String mealId) =>
      '$userId/$mealId.jpg';
}
