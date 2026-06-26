import 'dart:io';

import 'package:flutter/foundation.dart';

import '../datasources/meal_local_datasource.dart';
import '../datasources/meal_remote_datasource.dart';
import 'meal_thumbnail_service.dart';
import '../../domain/entities/meal_entry_entity.dart';

/// Premium-only meal cloud sync: write-through on save/delete, bulk upload of
/// pending local meals (e.g. right after the user upgrades), and a pull+merge
/// that restores cloud meals on a fresh install / new device.
///
/// Every method is best-effort and swallows its own errors: a failed cloud
/// write must never break the local-first meal flow. Unsynced rows keep
/// `syncStatus = 'local_only'` and get retried by [uploadPending] on the next
/// premium session.
class MealSyncService {
  final MealLocalDataSource _local;
  final MealRemoteDataSource _remote;
  final MealThumbnailService _thumbnails;

  MealSyncService(this._local, this._remote, this._thumbnails);

  /// Users whose full sync already ran this app session (so opening the meals
  /// screen repeatedly doesn't re-run the upload+pull every rebuild).
  final Set<String> _fullySyncedUsers = {};

  /// Push one meal to the cloud (photo first, then row), then flag it synced.
  /// Safe to call fire-and-forget right after a local save.
  Future<void> pushMeal(MealEntryEntity meal) async {
    try {
      String? photoUrl;
      final localPath = meal.photoThumbnailPath;
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          photoUrl = await _remote.uploadPhoto(
            userId: meal.userId,
            mealId: meal.id,
            file: file,
          );
        }
      }
      await _remote.upsert(meal, photoUrl: photoUrl);
      await _local.markSynced(meal.id);
    } catch (e) {
      debugPrint('[MealSync] pushMeal ${meal.id} failed: $e');
    }
  }

  /// Remove a meal from the cloud (row + photo). Local deletion is the
  /// caller's responsibility and already happened.
  Future<void> deleteMeal({required String id, required String userId}) async {
    try {
      await _remote.deleteRow(id);
      await _remote.deletePhoto(MealRemoteDataSource.photoPath(userId, id));
    } catch (e) {
      debugPrint('[MealSync] deleteMeal $id failed: $e');
    }
  }

  /// Upload every local meal still marked unsynced. Returns true if any were
  /// pending (the caller can refresh the UI).
  Future<bool> uploadPending(String userId) async {
    try {
      final pending = await _local.getUnsyncedMeals(userId);
      for (final meal in pending) {
        await pushMeal(meal);
      }
      return pending.isNotEmpty;
    } catch (e) {
      debugPrint('[MealSync] uploadPending failed: $e');
      return false;
    }
  }

  /// Pull cloud meals into local Drift, last-write-wins by `updatedAt`.
  /// Downloads each photo that isn't already on this device. Returns true if
  /// any local row was added/updated.
  Future<bool> pullAndMerge(String userId) async {
    try {
      final cloud = await _remote.fetchAll(userId);
      var changed = false;
      for (final row in cloud) {
        final id = row['id'] as String?;
        if (id == null) continue;

        final cloudUpdated =
            DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final local = await _local.getMealById(id);
        if (local != null) {
          final localUpdated =
              local.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          if (!cloudUpdated.isAfter(localUpdated)) continue; // local is current
        }

        // Reuse an existing local thumbnail; otherwise download from Storage.
        var thumbPath = local?.photoThumbnailPath;
        if (thumbPath != null && !File(thumbPath).existsSync()) thumbPath = null;
        final photoUrl = row['photo_url'] as String?;
        if (thumbPath == null && photoUrl != null) {
          final bytes = await _remote.downloadPhoto(photoUrl);
          if (bytes != null) {
            thumbPath = await _thumbnails.writeDownloaded(
              mealId: id,
              bytes: bytes,
            );
          }
        }

        await _local.saveMeal(
          MealRemoteDataSource.rowToEntity(row, thumbnailPath: thumbPath),
        );
        await _local.markSynced(id);
        changed = true;
      }
      return changed;
    } catch (e) {
      debugPrint('[MealSync] pullAndMerge failed: $e');
      return false;
    }
  }

  /// One full reconcile per user per app session: upload pending local meals,
  /// then pull cloud meals down. Returns true if anything changed locally so
  /// the caller can invalidate the meal providers.
  Future<bool> fullSyncOnce(String userId) async {
    if (_fullySyncedUsers.contains(userId)) return false;
    _fullySyncedUsers.add(userId);
    final uploaded = await uploadPending(userId);
    final pulled = await pullAndMerge(userId);
    return uploaded || pulled;
  }
}
